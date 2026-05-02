/**
 * Per-app overrides for winget manifests that point at unreliable hosts.
 *
 * SourceForge mirrors fail frequently (Cloudflare challenges, dead mirrors,
 * rate limits). Some projects publish the same binary to a more reliable host
 * (e.g. GitHub Releases). The winget manifest's pinned SHA256 still applies,
 * so a wrong override URL fails fast with HASH_MISMATCH at the workflow.
 */

/**
 * Builds an override URL for the given winget id. Return `null` to fall
 * through to the manifest's original URL. Implementations that ignore the
 * `architecture` parameter are only safe when the app ships a single
 * universal installer.
 */
type OverrideFn = (version: string, architecture: string) => string | null;

export const INSTALLER_URL_OVERRIDES: Record<string, OverrideFn> = {
  'Freeplane.Freeplane': (version) =>
    `https://github.com/freeplane/freeplane/releases/download/release-${version}/Freeplane-Setup-${version}.exe`,

  // WinSCP winget manifest points at SourceForge (/download mirror-selection page).
  // The packager's SourceForge mirror-retry logic exhausts all mirrors in CI.
  // winscp.net/download/<version>-Setup.exe is their canonical URL and resolves
  // to a direct binary without triggering the packager's SF-specific code path.
  'WinSCP.WinSCP': (version) =>
    `https://winscp.net/download/WinSCP-${version}-Setup.exe`,

  // PowerShell's winget manifest lists the msixbundle first. Intune rejects MSIX
  // wrapped in intunewin for win32LobApp. Use the arch-specific MSI from GitHub
  // Releases instead. winget version is "7.6.1.0"; GitHub tag drops the trailing .0.
  'Microsoft.PowerShell': (version, architecture) => {
    const ver = version.replace(/\.0$/, '');
    const arch = architecture === 'x86' ? 'x86' : architecture === 'arm64' ? 'arm64' : 'x64';
    return `https://github.com/PowerShell/PowerShell/releases/download/v${ver}/PowerShell-${ver}-win-${arch}.msi`;
  },
};

export function applyInstallerUrlOverride(
  wingetId: string,
  version: string,
  architecture: string,
  originalUrl: string,
): string {
  const fn = INSTALLER_URL_OVERRIDES[wingetId];
  if (!fn) return originalUrl;
  return fn(version, architecture) ?? originalUrl;
}
