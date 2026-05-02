/**
 * Cancel Package API Route
 * Cancels pending or in-process packaging jobs
 */

import { NextRequest, NextResponse } from 'next/server';
import { getDatabase } from '@/lib/db';
import { cancelWorkflowRun, isGitHubActionsConfigured } from '@/lib/github-actions';
import { parseAccessToken } from '@/lib/auth-utils';
import { handleAutoUpdateJobCompletion } from '@/lib/auto-update/cleanup';

interface CancelRequestBody {
  jobId: string;
  dismiss?: boolean;
}

// Statuses that can be cancelled (active jobs)
const CANCELLABLE_STATUSES = ['queued', 'packaging', 'uploading'];
// Statuses that can be force-dismissed by the user
const DISMISSABLE_STATUSES = ['queued', 'packaging', 'uploading', 'completed', 'failed', 'cancelled', 'duplicate_skipped', 'deployed'];

export async function POST(request: NextRequest) {
  try {
    const user = await parseAccessToken(request.headers.get('Authorization'));
    if (!user) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      );
    }

    const userId = user.userId;
    const userEmail = user.userEmail;

    const body: CancelRequestBody = await request.json();
    const { jobId, dismiss } = body;

    if (!jobId) {
      return NextResponse.json(
        { error: 'jobId is required' },
        { status: 400 }
      );
    }

    const db = getDatabase();
    const job = await db.jobs.getById(jobId);

    if (!job) {
      return NextResponse.json(
        { error: 'Job not found' },
        { status: 404 }
      );
    }

    // Verify the user owns this job
    if (job.user_id !== userId) {
      return NextResponse.json(
        { error: 'You do not have permission to cancel this job' },
        { status: 403 }
      );
    }

    // If dismiss flag is set and job is in a terminal state, delete the row
    const terminalStatuses = ['completed', 'failed', 'cancelled', 'duplicate_skipped', 'deployed'];
    if (dismiss && terminalStatuses.includes(job.status)) {
      const isAutoUpdate = (job as unknown as Record<string, unknown>).is_auto_update;
      if (isAutoUpdate) {
        const dismissStatus = (job.status === 'deployed' || job.status === 'duplicate_skipped')
          ? job.status as 'deployed' | 'duplicate_skipped'
          : 'cancelled';
        await handleAutoUpdateJobCompletion(jobId, dismissStatus).catch((err) => {
          console.error('[Cancel] Auto-update cleanup error on dismiss:', err);
        });
      }
      await db.jobs.deleteById(jobId);
      return NextResponse.json({
        success: true,
        message: 'Job dismissed and removed',
        jobId,
        deleted: true,
      });
    }

    if (job.status === 'cancelled') {
      return NextResponse.json({
        success: true,
        message: 'Job is already cancelled',
        jobId,
        githubCancelled: null,
      });
    }

    if (job.status === 'deployed') {
      return NextResponse.json(
        { error: 'Cannot cancel a deployed job. It is already in Intune.' },
        { status: 400 }
      );
    }

    if (!DISMISSABLE_STATUSES.includes(job.status)) {
      return NextResponse.json(
        { error: `Job cannot be cancelled. Current status: ${job.status}` },
        { status: 400 }
      );
    }

    // Attempt to cancel GitHub workflow if run ID exists and job is still active
    let githubCancelResult = null;
    const isActiveJob = CANCELLABLE_STATUSES.includes(job.status);
    if (isActiveJob && job.github_run_id && isGitHubActionsConfigured()) {
      githubCancelResult = await cancelWorkflowRun(job.github_run_id);
    }

    const cancelledByEmail = userEmail || job.user_email || 'unknown';
    const errorMessage = !isActiveJob
      ? `Job dismissed by user (was ${job.status})`
      : githubCancelResult && !githubCancelResult.success
        ? `Job cancelled by user. GitHub workflow: ${githubCancelResult.message}`
        : 'Job cancelled by user';

    await db.jobs.update(jobId, {
      status: 'cancelled',
      cancelled_at: new Date().toISOString(),
      cancelled_by: cancelledByEmail,
      error_message: errorMessage,
    });

    handleAutoUpdateJobCompletion(jobId, 'cancelled', errorMessage).catch((err) => {
      console.error('[Cancel] Auto-update cleanup error:', err);
    });

    return NextResponse.json({
      success: true,
      message: 'Job cancelled successfully',
      jobId,
      githubCancelled: githubCancelResult?.success ?? null,
    });
  } catch {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
