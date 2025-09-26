# Propelus Taxonomy Workflows Documentation

## Overview
Based on the September 24 meeting, there are two distinct workflows in the system:
1. **Mapping Creation Workflow** (Left-to-Right): Creating new mappings between taxonomies
2. **Translation Workflow** (Right-to-Left): Using established mappings for real-time translation

## Workflow 1: Mapping Creation (Left-to-Right)

### Purpose
Create and validate mappings between customer taxonomies/professions and the master Propelus taxonomy.

### Input Data from Customers
Customers typically provide minimal flat data (NOT hierarchical taxonomies):
- **State** (e.g., "WA", "CA")
- **Client Profession Code** (e.g., "ARNP", "ACLS")
- **Client Profession Description** (e.g., "Advanced Registered Nurse Practitioner")
- **Issuing Authority** (optional, rarely provided)

### Process Flow
```
Customer Data → Bronze Layer → Silver Layer Processing → Mapping Rules → Human Review → Gold Layer
```

### Detailed Steps

#### 1. Data Ingestion (Bronze Layer)
- Raw data stored in `bronze_professions` or `bronze_taxonomies`
- Minimal transformation, preserves original format

#### 2. Data Processing (Silver Layer)
- Parse and structure the data
- Store in `silver_professions` with attributes
- Track unique attribute combinations in `silver_attribute_combinations`

#### 3. Apply Mapping Rules
Priority-based execution:
1. **Context Rules** (Priority 1-10)
   - Check for overrides (e.g., ARRT always = national cert)
   - Apply abbreviation rules (e.g., ACLS = American Heart Association)

2. **Exact Match** (Priority 11-30)
   - Direct code matching
   - Case-insensitive comparison

3. **Pattern/Regex Rules** (Priority 31-50)
   - Pattern matching with stored rules
   - Handle variations and formats

4. **Fuzzy Matching** (Priority 51-80)
   - Edit distance calculations
   - Similarity scoring

5. **AI/LLM Matching** (Priority 81-100)
   - Semantic similarity
   - Context-aware matching

#### 4. Confidence Scoring
- **100%**: Exact match or deterministic rule
- **80-99%**: High confidence (may auto-approve based on settings)
- **60-79%**: Medium confidence (requires human review)
- **<60%**: Low confidence (requires human intervention)

#### 5. Human-in-the-Loop Review
For mappings with confidence < threshold:
- Present multiple options with confidence scores
- Show context and similar mappings
- Human selects correct mapping or creates new one
- System learns from decisions

#### 6. Promotion to Gold Layer
- Approved mappings stored in `gold_taxonomies_mapping` or `gold_mapping_professions`
- Becomes available for translation workflow

### Key Tables Used
- `bronze_professions` - Raw input data
- `silver_professions` - Structured profession data
- `silver_attribute_combinations` - Unique attribute patterns
- `silver_context_rules` - Disambiguation rules
- `silver_issuing_authorities` - Authority definitions
- `silver_mapping_professions` - Candidate mappings
- `gold_mapping_professions` - Approved mappings

## Workflow 2: Translation (Right-to-Left)

### Purpose
Translate profession codes between taxonomies using established mappings (real-time, deterministic).

### Process Flow
```
API Request → Validate → Lookup Mappings → Apply Rules → Return Result(s)
```

### API Contract

#### Request
```json
POST /api/v1/translate
{
  "source_taxonomy": "client_a",  // or taxonomy_id
  "target_taxonomy": "evercheck",  // or taxonomy_id
  "source_code": "ARNP",
  "attributes": {
    "state": "WA",
    "issuing_authority": "Washington State Nursing Commission"
  }
}
```

#### Response Scenarios

**Single Match (Ideal)**
```json
{
  "status": "success",
  "results": [
    {
      "target_code": "ARNP-01",
      "confidence": 100,
      "profession_name": "Advanced Registered Nurse Practitioner",
      "authority": "Washington State Nursing Commission"
    }
  ]
}
```

**Multiple Matches (Insufficient Attributes)**
```json
{
  "status": "multiple_matches",
  "message": "Additional attributes needed for unique match",
  "results": [
    {
      "target_code": "ARNP-01",
      "profession_name": "Advanced Registered Nurse Practitioner",
      "required_state": "WA"
    },
    {
      "target_code": "ARNP-02",
      "profession_name": "Advanced Registered Nurse Practitioner - Anesthetist",
      "required_state": "WA"
    }
  ]
}
```

**No Match**
```json
{
  "status": "no_match",
  "message": "No mapping found for the provided combination",
  "source_code": "UNKNOWN123"
}
```

### Translation Process

#### 1. Input Validation
- Verify source and target taxonomies exist
- Validate required attributes are present

#### 2. Determine Path
- **Path 1**: Direct mapping if exists (Customer A → Customer B)
- **Path 2**: Through master (Customer A → Master → Customer B)

#### 3. Apply Context Rules
- Check `silver_context_rules` for overrides
- Apply issuing authority rules
- Handle special cases (e.g., ARRT overrides state)

#### 4. Lookup Mappings
- Query Gold layer tables for approved mappings
- Filter by provided attributes
- Return all matches if multiple exist

#### 5. Return Results
- Single result if unique match
- Multiple results if ambiguous (client decides)
- Empty result if no mapping exists

### Key Characteristics
- **No Human Intervention**: Fully automated
- **Deterministic**: Same input always produces same output
- **Real-time**: Sub-second response times
- **Flexible**: Can return multiple matches, letting client decide

### Tables Used
- `gold_taxonomies_mapping` - Approved taxonomy mappings
- `gold_mapping_professions` - Approved profession mappings
- `silver_context_rules` - Context and override rules
- `silver_issuing_authorities` - Authority information

## Special Cases and Rules

### National Certifications vs State Licenses
Some codes override state attributes:
- **ARRT** (American Registry of Radiologic Technologists) - Always national
- **ACLS** (Advanced Cardiovascular Life Support) - American Heart Association
- **BLS** (Basic Life Support) - American Heart Association
- **PALS** (Pediatric Advanced Life Support) - American Heart Association

### Disambiguation Rules
When abbreviations have multiple meanings:
- **RQI**: Could be different based on context
  - With "Heart" → American Heart Association
  - Otherwise → Check additional attributes

### Priority Hierarchies
1. National certification authorities (override state)
2. State-specific licenses
3. Facility-specific credentials

## Data Storage Principles

### What to Store
Per the meeting discussion with Kristen and Edwin:
- **Store each unique combination seen**
  - Washington + ARNP → Store
  - California + ARNP → Store separately
  - ARNP (no state) → Store as separate entry
- **Don't store individual requests** (use logs for that)
- **Store patterns for analysis**

### Attribute Combination Tracking
The `silver_attribute_combinations` table tracks:
- Every unique combination of attributes
- Frequency of occurrence
- Mapping success/failure
- Confidence levels achieved

This helps:
- Identify patterns requiring new rules
- Find common ambiguities
- Improve mapping accuracy over time

## Implementation Notes

### For EverCheck
- Has its own taxonomy
- Each client has their taxonomy
- Need to map: Client → Master → EverCheck
- Focus on verification methods (automated/manual)

### For Data Solutions
- Uses same underlying data as EverCheck
- Less standardized input data
- Same mapping logic applies
- API-based, no internal taxonomy

### Common Challenges
1. **Missing Context**: Clients don't always provide issuing authority
2. **Abbreviation Ambiguity**: Same abbreviation, different meanings
3. **Evolution**: New authorities and credentials added over time
4. **State Variations**: Same profession, different codes by state

## Success Metrics

### Mapping Creation
- % of auto-mapped (high confidence)
- % requiring human review
- Average time to resolve ambiguities
- Mapping accuracy rate

### Translation Service
- Response time (<100ms target)
- Single match rate (ideal)
- Multiple match rate (needs improvement)
- No match rate (gaps to address)