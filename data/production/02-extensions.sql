-- ============================================================================
-- Production Aurora PostgreSQL - Extensions Setup
-- ============================================================================
-- Description: Install required PostgreSQL extensions
-- Environment: Aurora PostgreSQL 15+
-- Prerequisites: Must be connected to 'taxonomy' database
-- ============================================================================

-- ============================================================================
-- TRIGRAM EXTENSION (pg_trgm)
-- ============================================================================
-- Purpose: Enables trigram-based text search and similarity matching
-- Used for: Fast fuzzy text matching in taxonomy names, profession values
-- Performance: GIN indexes with gin_trgm_ops for efficient LIKE queries

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================================
-- PGCRYPTO EXTENSION
-- ============================================================================
-- Purpose: Cryptographic functions for data security
-- Used for: Hashing, encryption, random value generation
-- Functions: gen_random_uuid(), crypt(), encrypt(), decrypt()

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check extensions installed
SELECT extname, extversion, nspname
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
WHERE extname IN ('pg_trgm', 'pgcrypto');

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- pg_trgm capabilities:
--   - Similarity matching: similarity('text1', 'text2')
--   - Fast LIKE queries: WHERE value LIKE '%pattern%' using GIN indexes
--   - Fuzzy search: WHERE value % 'pattern' (similar to)
--
-- pgcrypto capabilities:
--   - UUID generation: gen_random_uuid()
--   - Password hashing: crypt(password, gen_salt('bf'))
--   - Encryption: pgp_sym_encrypt(data, key)
--
-- ============================================================================
