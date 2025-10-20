# NLP Qualifier Matching - Integration Overview

## Summary

Integrate the architect's deterministic NLP pipeline from `TaxonomyPipelineTaxonomy.ipynb` into **Mapping Rules Lambda (Lambda #3)** as a new matching strategy.

## Current State

### Lambda #3 Current Matchers
1. **Exact Matcher** - Case-insensitive exact match (100% confidence)
2. **Fuzzy Matcher** - Levenshtein distance (70-90% confidence)
3. **AI Semantic Matcher** - AWS Bedrock Claude/Llama (variable confidence)

### Gap
No intermediate strategy between exact and fuzzy matching for **qualifier-aware patterns**.

## What the Architect's Notebook Provides

### Key Features
1. **Qualifier-Aware Matching** - Understands context before/after head terms
2. **Vocabulary Extraction** - Builds matching dictionaries from taxonomy hierarchy
3. **Strong vs Qualified Heads** - Differentiates high-confidence vs contextual terms
4. **Token-Level Pattern Matching** - Uses linguistic tokenization
5. **Multi-Level Hierarchy Support** - Matches across Industry → Occupation Level

### Example Patterns
```
Qualified Suffix:  QUALIFIER + HEAD
  "Clinical Social Worker" → "Clinical" (qualifier) + "Social Worker" (head)

Qualified Prefix:  HEAD + QUALIFIER
  "Nurse Practitioner" → "Nurse" (head) + "Practitioner" (qualifier)

Strong Occupation: Multi-word detailed occupation
  "Advanced Psychiatric Nurse" → High confidence match
```

## Integration Plan

### Add as 3rd Matcher in Lambda #3

**New Matching Hierarchy:**
1. Exact Matcher (100%) - Unchanged
2. **NLP Qualifier Matcher (90-95%)** ← NEW
3. Fuzzy Matcher (70-90%) - Unchanged
4. AI Semantic (variable) - Unchanged

### Implementation Location
```
lambdas/mapping_rules/
└── src/
    └── matchers/
        ├── exact-matcher.ts        (existing)
        ├── fuzzy-matcher.ts        (existing)
        ├── nlp-qualifier-matcher.ts  ← NEW
        └── ai-semantic-matcher.ts  (existing)
```

### Dependencies to Add
- **Option A**: `compromise` (pure JavaScript NLP library, ~300KB)
- **Option B**: `spacy` (Python wrapper, requires Python runtime)
- **Recommended**: Option A (compromise) for Lambda compatibility

### Database Schema Impact
**No schema changes required** - uses existing `silver_taxonomies_nodes` hierarchy.

## Technical Approach

### Phase 1: Vocabulary Extraction
Query taxonomy hierarchy to build:
- Strong heads (multi-word detailed occupations)
- Qualified heads (generic terms: nurse, therapist, worker)
- Qualifiers (industry names, minor groups, prefixes)

### Phase 2: Matcher Implementation
Create TypeScript matcher that:
1. Normalizes input text
2. Tokenizes with linguistic awareness
3. Applies pattern matching rules:
   - Strong occupation patterns
   - Qualified suffix patterns (QUALIFIER + HEAD)
   - Qualified prefix patterns (HEAD + QUALIFIER)
4. Returns match with 90-95% confidence

### Phase 3: Integration
Update `mapping-engine.ts` to call NLP matcher between exact and fuzzy.

## Benefits

1. **Higher Match Quality** - Understands "Clinical Nurse" ≠ "Nurse"
2. **Better Confidence Scoring** - 90-95% vs 70% fuzzy fallback
3. **Fewer AI Calls** - Reduces expensive Bedrock invocations
4. **Human Review Reduction** - More accurate automatic mapping
5. **Taxonomy-Aware** - Uses actual hierarchy structure

## Success Criteria

- [ ] NLP matcher integrated into Lambda #3
- [ ] Vocabulary extraction from taxonomy working
- [ ] Match confidence scores between 90-95%
- [ ] Qualifier patterns working (suffix and prefix)
- [ ] Unit tests for all pattern types
- [ ] Performance: <100ms per node match

## Next Steps

1. Create detailed matcher specification
2. Implement vocabulary extractor
3. Implement NLP qualifier matcher
4. Add unit tests
5. Update mapping engine
6. Update Lambda README

## References

- Source: `docs/nlp/TaxonomyPipelineTaxonomy.ipynb`
- Lambda: `lambdas/mapping_rules/`
- Target Integration: Between exact and fuzzy matchers
