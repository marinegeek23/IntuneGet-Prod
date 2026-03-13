-- Fix: Search returning wrong Notepad variant (Issue #44)
--
-- PostgreSQL's websearch_to_tsquery('english', 'Notepad++') strips the '++'
-- characters, reducing the query to just "notepad". This matches all Notepad
-- variants with equal FTS rank. The ORDER BY then falls to popularity_rank,
-- which may not favor the exact match.
--
-- Fix: Add exact/prefix match boosting to the FTS branch's ORDER BY via a
-- CASE expression, so the correct app always sorts first when FTS scores tie.

DROP FUNCTION IF EXISTS search_curated_apps(TEXT, TEXT, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION search_curated_apps(
  search_query TEXT,
  category_filter TEXT DEFAULT NULL,
  result_limit INTEGER DEFAULT 50,
  result_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id INTEGER,
  winget_id TEXT,
  name TEXT,
  publisher TEXT,
  latest_version TEXT,
  description TEXT,
  homepage TEXT,
  category TEXT,
  tags TEXT[],
  icon_path TEXT,
  popularity_rank INTEGER,
  rank REAL,
  app_source TEXT,
  store_package_id TEXT
)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  fts_count INTEGER;
BEGIN
  -- First, try full-text search
  RETURN QUERY
  SELECT
    ca.id,
    ca.winget_id,
    ca.name,
    ca.publisher,
    ca.latest_version,
    ca.description,
    ca.homepage,
    ca.category,
    ca.tags,
    ca.icon_path,
    ca.popularity_rank,
    ts_rank_cd(ca.fts, websearch_to_tsquery('english', search_query)) AS rank,
    ca.app_source,
    ca.store_package_id
  FROM curated_apps ca
  WHERE
    ca.fts @@ websearch_to_tsquery('english', search_query)
    AND (category_filter IS NULL OR ca.category = category_filter)
    AND ca.is_verified = TRUE
    AND ca.is_locale_variant = FALSE
  ORDER BY
    CASE
      WHEN LOWER(ca.name) = LOWER(search_query) THEN 0
      WHEN LOWER(ca.winget_id) = LOWER(search_query) THEN 0
      WHEN ca.winget_id ILIKE '%.' || search_query THEN 0
      WHEN LOWER(ca.name) LIKE LOWER(search_query) || '%' THEN 1
      WHEN ca.winget_id ILIKE '%.' || search_query || '%' THEN 1
      ELSE 2
    END,
    rank DESC,
    ca.popularity_rank ASC NULLS LAST
  LIMIT result_limit
  OFFSET result_offset;

  -- Check if FTS returned any results
  GET DIAGNOSTICS fts_count = ROW_COUNT;

  -- If FTS returned no results, fallback to ILIKE pattern matching
  IF fts_count = 0 THEN
    RETURN QUERY
    SELECT
      ca.id,
      ca.winget_id,
      ca.name,
      ca.publisher,
      ca.latest_version,
      ca.description,
      ca.homepage,
      ca.category,
      ca.tags,
      ca.icon_path,
      ca.popularity_rank,
      0.0::REAL AS rank,
      ca.app_source,
      ca.store_package_id
    FROM curated_apps ca
    WHERE
      (
        ca.name ILIKE '%' || search_query || '%'
        OR ca.winget_id ILIKE '%' || search_query || '%'
        OR ca.publisher ILIKE '%' || search_query || '%'
      )
      AND (category_filter IS NULL OR ca.category = category_filter)
      AND ca.is_verified = TRUE
      AND ca.is_locale_variant = FALSE
    ORDER BY
      CASE
        WHEN LOWER(ca.name) = LOWER(search_query) THEN 1
        WHEN LOWER(ca.name) LIKE LOWER(search_query) || '%' THEN 2
        WHEN LOWER(ca.winget_id) LIKE '%' || LOWER(search_query) || '%' THEN 3
        ELSE 4
      END,
      ca.popularity_rank ASC NULLS LAST
    LIMIT result_limit
    OFFSET result_offset;
  END IF;
END;
$$;
