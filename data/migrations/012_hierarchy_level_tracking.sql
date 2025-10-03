-- Migration 012: Hierarchy Level Tracking for Variable-Depth Mappings
-- Purpose: Support mappings to any hierarchy level (not just leaf nodes)
-- Based on Sept 30 meeting requirement: "One profession code might point to the
-- third level and another one in the same list might point to the fourth level"

-- =============================================================================
-- ADD HIERARCHY LEVEL TRACKING TO NODES
-- =============================================================================

-- Add explicit hierarchy level to taxonomy nodes
ALTER TABLE silver_taxonomies_nodes
ADD COLUMN IF NOT EXISTS hierarchy_level VARCHAR(50);

-- Add constraint for valid hierarchy levels
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_hierarchy_level'
    ) THEN
        ALTER TABLE silver_taxonomies_nodes
        ADD CONSTRAINT chk_hierarchy_level
        CHECK (hierarchy_level IN (
            'industry',
            'broad_occupation',
            'profession_group',
            'specialty_group',
            'occupation_specialty',
            'occupation_status'
        ));
    END IF;
END $$;

-- Create index for hierarchy level queries
CREATE INDEX IF NOT EXISTS idx_silver_taxonomies_nodes_hierarchy_level
ON silver_taxonomies_nodes(hierarchy_level, taxonomy_id);

COMMENT ON COLUMN silver_taxonomies_nodes.hierarchy_level IS 'Named hierarchy level: industry, broad_occupation, profession_group, specialty_group, occupation_specialty, occupation_status';

-- =============================================================================
-- ADD TARGET HIERARCHY LEVEL TO MAPPINGS
-- =============================================================================

-- Track which hierarchy level a mapping targets
ALTER TABLE silver_mapping_professions
ADD COLUMN IF NOT EXISTS target_hierarchy_level VARCHAR(50),
ADD COLUMN IF NOT EXISTS detected_hierarchy_level VARCHAR(50),
ADD COLUMN IF NOT EXISTS hierarchy_level_confidence DECIMAL(5,2);

-- Add constraint
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_profession_mapping_hierarchy'
    ) THEN
        ALTER TABLE silver_mapping_professions
        ADD CONSTRAINT chk_profession_mapping_hierarchy
        CHECK (target_hierarchy_level IN (
            'industry',
            'broad_occupation',
            'profession_group',
            'specialty_group',
            'occupation_specialty',
            'occupation_status'
        ));
    END IF;
END $$;

-- Same for taxonomy mappings
ALTER TABLE silver_mapping_taxonomies
ADD COLUMN IF NOT EXISTS target_hierarchy_level VARCHAR(50),
ADD COLUMN IF NOT EXISTS detected_hierarchy_level VARCHAR(50),
ADD COLUMN IF NOT EXISTS hierarchy_level_confidence DECIMAL(5,2);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_taxonomy_mapping_hierarchy'
    ) THEN
        ALTER TABLE silver_mapping_taxonomies
        ADD CONSTRAINT chk_taxonomy_mapping_hierarchy
        CHECK (target_hierarchy_level IN (
            'industry',
            'broad_occupation',
            'profession_group',
            'specialty_group',
            'occupation_specialty',
            'occupation_status'
        ));
    END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_silver_mapping_professions_hierarchy
ON silver_mapping_professions(target_hierarchy_level, status);

CREATE INDEX IF NOT EXISTS idx_silver_mapping_taxonomies_hierarchy
ON silver_mapping_taxonomies(target_hierarchy_level, status);

-- Add comments
COMMENT ON COLUMN silver_mapping_professions.target_hierarchy_level IS 'The hierarchy level of the target taxonomy node this maps to';
COMMENT ON COLUMN silver_mapping_professions.detected_hierarchy_level IS 'The hierarchy level detected from the profession name/attributes';
COMMENT ON COLUMN silver_mapping_professions.hierarchy_level_confidence IS 'Confidence that this is the correct hierarchy level (0-100)';

COMMENT ON COLUMN silver_mapping_taxonomies.target_hierarchy_level IS 'The hierarchy level of the target taxonomy node this maps to';
COMMENT ON COLUMN silver_mapping_taxonomies.detected_hierarchy_level IS 'The hierarchy level detected from source taxonomy';
COMMENT ON COLUMN silver_mapping_taxonomies.hierarchy_level_confidence IS 'Confidence that this is the correct hierarchy level (0-100)';

-- =============================================================================
-- GOLD LAYER HIERARCHY TRACKING
-- =============================================================================

-- Add hierarchy level to gold mappings for query optimization
ALTER TABLE gold_mapping_professions
ADD COLUMN IF NOT EXISTS target_hierarchy_level VARCHAR(50);

ALTER TABLE gold_taxonomies_mapping
ADD COLUMN IF NOT EXISTS target_hierarchy_level VARCHAR(50);

CREATE INDEX IF NOT EXISTS idx_gold_mapping_professions_hierarchy
ON gold_mapping_professions(target_hierarchy_level);

CREATE INDEX IF NOT EXISTS idx_gold_taxonomies_mapping_hierarchy
ON gold_taxonomies_mapping(target_hierarchy_level);

COMMENT ON COLUMN gold_mapping_professions.target_hierarchy_level IS 'Cached hierarchy level for fast queries';
COMMENT ON COLUMN gold_taxonomies_mapping.target_hierarchy_level IS 'Cached hierarchy level for fast queries';

-- =============================================================================
-- HELPER VIEWS FOR HIERARCHY-LEVEL QUERIES
-- =============================================================================

-- View for mappings grouped by hierarchy level
CREATE OR REPLACE VIEW v_mappings_by_hierarchy_level AS
SELECT
    'profession' as mapping_type,
    smp.target_hierarchy_level as hierarchy_level,
    COUNT(*) as mapping_count,
    AVG(smp.confidence) as avg_confidence,
    sp.customer_id
FROM silver_mapping_professions smp
JOIN silver_professions sp ON smp.profession_id = sp.profession_id
WHERE smp.is_active = TRUE
  AND smp.target_hierarchy_level IS NOT NULL
GROUP BY smp.target_hierarchy_level, sp.customer_id

UNION ALL

SELECT
    'taxonomy' as mapping_type,
    smt.target_hierarchy_level as hierarchy_level,
    COUNT(*) as mapping_count,
    AVG(smt.confidence) as avg_confidence,
    source_tax.customer_id
FROM silver_mapping_taxonomies smt
JOIN silver_taxonomies_nodes sn ON smt.node_id = sn.node_id
JOIN silver_taxonomies source_tax ON sn.taxonomy_id = source_tax.taxonomy_id
WHERE smt.is_active = TRUE
  AND smt.target_hierarchy_level IS NOT NULL
GROUP BY smt.target_hierarchy_level, source_tax.customer_id;

COMMENT ON VIEW v_mappings_by_hierarchy_level IS 'Statistics on mappings grouped by target hierarchy level';

-- View for variable-depth mapping analysis
CREATE OR REPLACE VIEW v_variable_depth_analysis AS
SELECT
    sp.customer_id,
    sp.name as profession_name,
    smp.target_hierarchy_level,
    smp.detected_hierarchy_level,
    CASE
        WHEN smp.target_hierarchy_level = smp.detected_hierarchy_level THEN 'exact_match'
        WHEN smp.target_hierarchy_level IS NULL THEN 'unmapped'
        WHEN smp.detected_hierarchy_level IS NULL THEN 'level_not_detected'
        ELSE 'level_mismatch'
    END as level_match_status,
    smp.hierarchy_level_confidence,
    smp.confidence as mapping_confidence,
    smp.status
FROM silver_mapping_professions smp
JOIN silver_professions sp ON smp.profession_id = sp.profession_id
WHERE smp.is_active = TRUE;

COMMENT ON VIEW v_variable_depth_analysis IS 'Analyzes how professions map to different hierarchy levels';

-- =============================================================================
-- FUNCTION: Auto-detect hierarchy level from node structure
-- =============================================================================

CREATE OR REPLACE FUNCTION detect_node_hierarchy_level(
    p_node_id INTEGER
)
RETURNS VARCHAR AS $$
DECLARE
    v_level INTEGER;
    v_hierarchy_level VARCHAR(50);
BEGIN
    -- Count parent levels to determine depth
    WITH RECURSIVE node_path AS (
        -- Start with the node
        SELECT
            node_id,
            parent_node_id,
            1 as depth
        FROM silver_taxonomies_nodes
        WHERE node_id = p_node_id

        UNION ALL

        -- Recursively get parents
        SELECT
            stn.node_id,
            stn.parent_node_id,
            np.depth + 1
        FROM silver_taxonomies_nodes stn
        INNER JOIN node_path np ON stn.node_id = np.parent_node_id
    )
    SELECT MAX(depth) INTO v_level
    FROM node_path;

    -- Map depth to hierarchy level name
    v_hierarchy_level := CASE v_level
        WHEN 1 THEN 'industry'
        WHEN 2 THEN 'broad_occupation'
        WHEN 3 THEN 'profession_group'
        WHEN 4 THEN 'specialty_group'
        WHEN 5 THEN 'occupation_specialty'
        WHEN 6 THEN 'occupation_status'
        ELSE 'occupation_specialty'  -- Default
    END;

    RETURN v_hierarchy_level;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION detect_node_hierarchy_level IS 'Auto-detects hierarchy level from node depth in tree';

-- =============================================================================
-- FUNCTION: Update hierarchy level for existing nodes
-- =============================================================================

CREATE OR REPLACE FUNCTION update_node_hierarchy_levels()
RETURNS INTEGER AS $$
DECLARE
    v_updated_count INTEGER := 0;
    v_node RECORD;
BEGIN
    FOR v_node IN
        SELECT node_id
        FROM silver_taxonomies_nodes
        WHERE hierarchy_level IS NULL
    LOOP
        UPDATE silver_taxonomies_nodes
        SET hierarchy_level = detect_node_hierarchy_level(v_node.node_id)
        WHERE node_id = v_node.node_id;

        v_updated_count := v_updated_count + 1;
    END LOOP;

    RETURN v_updated_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_node_hierarchy_levels IS 'Backfills hierarchy_level for existing nodes';

-- =============================================================================
-- DATA MIGRATION: Backfill hierarchy levels
-- =============================================================================

-- Update hierarchy levels for existing nodes
SELECT update_node_hierarchy_levels();

-- Update mappings with target hierarchy level from their target nodes
UPDATE silver_mapping_professions smp
SET target_hierarchy_level = stn.hierarchy_level
FROM silver_taxonomies_nodes stn
WHERE smp.node_id = stn.node_id
  AND smp.target_hierarchy_level IS NULL
  AND stn.hierarchy_level IS NOT NULL;

UPDATE silver_mapping_taxonomies smt
SET target_hierarchy_level = stn.hierarchy_level
FROM silver_taxonomies_nodes stn
WHERE smt.master_node_id = stn.node_id
  AND smt.target_hierarchy_level IS NULL
  AND stn.hierarchy_level IS NOT NULL;

-- Update gold layer with hierarchy levels
UPDATE gold_mapping_professions gmp
SET target_hierarchy_level = stn.hierarchy_level
FROM silver_taxonomies_nodes stn
WHERE gmp.node_id = stn.node_id
  AND gmp.target_hierarchy_level IS NULL
  AND stn.hierarchy_level IS NOT NULL;

UPDATE gold_taxonomies_mapping gtm
SET target_hierarchy_level = stn.hierarchy_level
FROM silver_taxonomies_nodes stn
WHERE gtm.master_node_id = stn.node_id
  AND gtm.target_hierarchy_level IS NULL
  AND stn.hierarchy_level IS NOT NULL;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

DO $$
DECLARE
    missing_items TEXT := '';
    nodes_without_level INTEGER;
    mappings_without_level INTEGER;
BEGIN
    -- Check column exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'silver_taxonomies_nodes' AND column_name = 'hierarchy_level') THEN
        missing_items := missing_items || 'silver_taxonomies_nodes.hierarchy_level, ';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'silver_mapping_professions' AND column_name = 'target_hierarchy_level') THEN
        missing_items := missing_items || 'silver_mapping_professions.target_hierarchy_level, ';
    END IF;

    -- Check data quality
    SELECT COUNT(*) INTO nodes_without_level
    FROM silver_taxonomies_nodes
    WHERE hierarchy_level IS NULL;

    SELECT COUNT(*) INTO mappings_without_level
    FROM silver_mapping_professions
    WHERE target_hierarchy_level IS NULL AND is_active = TRUE;

    IF LENGTH(missing_items) > 0 THEN
        RAISE EXCEPTION 'Migration 012 incomplete. Missing: %', missing_items;
    END IF;

    IF nodes_without_level > 0 THEN
        RAISE WARNING '% nodes still missing hierarchy_level', nodes_without_level;
    END IF;

    IF mappings_without_level > 0 THEN
        RAISE WARNING '% active mappings still missing target_hierarchy_level', mappings_without_level;
    END IF;

    RAISE NOTICE 'Migration 012 completed - Variable-depth hierarchy mapping support added';
    RAISE NOTICE 'Nodes with hierarchy level: %', (SELECT COUNT(*) FROM silver_taxonomies_nodes WHERE hierarchy_level IS NOT NULL);
    RAISE NOTICE 'Mappings with target level: %', (SELECT COUNT(*) FROM silver_mapping_professions WHERE target_hierarchy_level IS NOT NULL);
END $$;

-- =============================================================================
-- SUMMARY
-- =============================================================================
-- Migration 012 implements variable-depth hierarchy mapping:
-- 1. ✅ hierarchy_level column added to silver_taxonomies_nodes
-- 2. ✅ target_hierarchy_level tracking in silver_mapping tables
-- 3. ✅ detected_hierarchy_level to track what level was detected from source
-- 4. ✅ hierarchy_level_confidence for mapping quality tracking
-- 5. ✅ Gold layer hierarchy tracking for performance
-- 6. ✅ Views for hierarchy-level analysis
-- 7. ✅ Helper functions for auto-detection and backfilling
-- 8. ✅ Data migration to populate existing records
--
-- Now supports: "Advanced Practice Registered Nurse" → broad_occupation (level 2)
--               "Temporary Physical Therapy Assistant" → occupation_status (level 6)
-- =============================================================================
