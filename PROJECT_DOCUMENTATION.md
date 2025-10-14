# Propelus Healthcare Taxonomy Project Documentation

## Executive Summary
The Propelus Taxonomy Framework is an AI-powered system for standardizing healthcare profession data by mapping customer profession lists (flat or hierarchical) directly to a single master taxonomy. It uses a three-layer data architecture (Bronze, Silver, Gold) with Lambda functions for processing, applying both deterministic rules and AI/LLM capabilities.

**Algorithm v1.0** implements revolutionary features including:
- **Rolling Ancestor Memory**: Parent resolution across rows using state management
- **Explicit Node Levels**: Numeric level indicators (0-N) for variable-depth hierarchies
- **Updated Natural Key**: Includes parent_node_id to allow same value under different parents
- **Profession Column**: Separate from hierarchy, stored on nodes but not as hierarchical level

**Last Updated**: October 14, 2024 - Algorithm v1.0 Production Ready
**Version**: 3.0.0
**Author**: Douglas Martins, Senior AI Engineer/Architect

## 🎯 Architecture Model (October 2024 - v1.0)

### Key Architectural Decisions
After extensive meetings, customer data analysis, and algorithm refinement:

**Architecture:**
- ✅ **ONE master taxonomy** maintained by Propelus (immutable, ~4 updates/year)
- ✅ **Variable customer taxonomies** - supports both flat lists and hierarchical structures
- ✅ **Algorithm v1.0** - Rolling ancestor memory for parent resolution
- ✅ **Explicit Node Levels** - Numeric indicators (0-N) for variable-depth hierarchies
- ✅ **Direct mapping**: Customer professions → Master taxonomy (no intermediate layers)
- ✅ **Request-based**: All interactions tracked with request_id for async operations
- ✅ **Remapping support**: Historical mappings reprocessed when master taxonomy updates
- ✅ **Updated Natural Key**: Includes parent_node_id to allow same value under different parents

**Customer Data Variability:**
Customers provide data in various formats:

**Flat Lists** (most common):
- Profession code (e.g., "RN", "ARNP", "LPN")
- Profession description (e.g., "Registered Nurse")
- State code (e.g., "CA", "WA", "FL")
- Optional: Issuing authority, license type, specialty

**Hierarchical Taxonomies** (variable depth):
- Example: `Social Worker → [skip level 2] → Associate`
- N/A placeholder nodes automatically fill hierarchy gaps
- Enables consistent mapping regardless of taxonomy depth

## System Architecture Overview

### Simplified Data Flow
```
Customer Profession List → Bronze Layer → Silver Layer → Gold Layer → APIs
   (API/File Upload)          ↓              ↓            ↓
                         (Raw Storage)   (Map to        (Approved
                                         Master         Mappings)
                                         Taxonomy)
```

### Core Workflows

#### 1. Primary Workflow: Profession Mapping (Left-to-Right)
```
Customer sends professions → Bronze ingestion → Apply mapping rules →
Human review (if needed) → Promote to Gold → Production ready
```
- Request ID tracking for async operations
- Webhook callbacks for completion notification
- Queue-based processing for batch operations

#### 2. Translation Service (Right-to-Left)
```
Query: "RN + CA" → Lookup in Gold mappings → Return master taxonomy match(es)
```
- Fully deterministic (no AI in translation)
- Real-time API responses
- Can return multiple matches if attributes insufficient

#### 3. Remapping Workflow (Rare, ~4x/year)
```
Master taxonomy updated → Version increment → Reprocess stored professions →
Generate new mapping versions → Review changes → Promote to Gold
```

---

## Master Taxonomy Attributes (October 2024 Update)

### Purpose
Master taxonomy nodes **SHOULD have attributes** to provide additional context for:
1. **LLM Matching**: Enhanced semantic understanding during customer→master mapping
2. **Business Rules**: Validation and filtering based on profession characteristics
3. **Reporting & Analytics**: Additional dimensions for analysis

### Attribute Categories

#### Level Attributes (Professional Standing)
Describes the credential or qualification level of a profession:
- **Licensed**: State-issued professional license
- **Certified**: National/organizational certification
- **Registered**: Registration with professional body
- **Supervisor**: Supervisory or advanced practice designation
- **Advanced Practice**: Higher level of autonomous practice

#### Status Attributes (Practice Status)
Describes the employment or practice status:
- **Temporary**: Time-limited credential or role
- **Volunteer**: Unpaid/volunteer capacity
- **Provisional**: Conditional or probationary status
- **Inactive**: Not currently practicing
- **Active**: Currently authorized to practice

### Example Master Taxonomy with Attributes

```
Industry (node) | Group (node) | Occupation (node) | Level (attribute) | Status (attribute)
Healthcare      | Medical      | Physician         | Licensed          | Active
Healthcare      | Medical      | Medical Assistant | Certified         | Active
Healthcare      | Nursing      | RN               | Licensed          | Active
Healthcare      | Nursing      | LPN              | Licensed          | Active
Healthcare      | Nursing      | RN               | Licensed          | Temporary
Healthcare      | Social Work  | LCSW             | Licensed          | Active
Healthcare      | Social Work  | LSW              | Licensed          | Provisional
```

### Benefits for LLM Processing

**Without Attributes**:
```
Customer Input: "Temporary Licensed Social Worker"
Master Match: "Social Worker" (generic, may miss temporal nature)
```

**With Attributes**:
```
Customer Input: "Temporary Licensed Social Worker"
Master Match: "Social Worker" + Level: "Licensed" + Status: "Temporary"
LLM Context: Full understanding of both credential level and temporal status
```

### Implementation in Data Model

**Already Supported** - The current algorithm (v0.2) and data model fully support master taxonomy attributes:

```sql
-- Master taxonomy nodes can have multiple attributes
silver_taxonomies_nodes (node hierarchy)
  ↓
silver_taxonomies_nodes_attributes (multi-value attributes)
  - attribute_type_id → "Level", "Status", "Specialty", etc.
  - value → "Licensed", "Temporary", "ICU", etc.
```

**Excel Format**:
```
Occupation (node) | Level (attribute) | Status (attribute)
Physician         | Licensed          | Active
```

**API Format**:
```json
{
  "layout": {
    "Nodes": ["Industry", "Group", "Occupation"],
    "Attributes": ["Level", "Status", "Specialty"]
  }
}
```

### Next Steps
- Kristen to populate master taxonomy with Level/Status attributes
- Identify additional attribute types from profession keyword analysis
- Test LLM matching improvement with enriched attributes

---

## Algorithm v1.0: Variable-Depth Hierarchy Handling (October 2024)

### Problem Statement
Healthcare taxonomies have inconsistent depths and require flexible parent resolution:
- **Master Taxonomy**: Variable levels (`Healthcare (0) → Behavioral Health (1) → Social Workers (2) → Clinical SW (3) → Advanced CSW (5)`) - skips level 4
- **Customer A**: 2 levels (`Social Worker → Associate`) - skips intermediate levels
- **Customer B**: Flat list (no hierarchy)
- **Requirement**: Same value (e.g., "Associate") can exist under different parents

### Solution: Algorithm v1.0 (Oct 14, 2024)

**Core Concepts**:

1. **Explicit Node Levels**: Each node has explicit numeric level (0-N)
   - Excel headers: `Industry (node 0)`, `Major Group (node 1)`, `Profession (node 5)`
   - API payload: `NodeLevels: [{ level: 0, name: "Industry" }, ...]`
   - Allows variable depth with gaps (e.g., 0, 1, 2, 5 - skipping 3, 4)

2. **Rolling Ancestor Memory**: Parent resolution across rows
   - Maintains `last_seen[level] = node_id` state
   - Each row creates exactly ONE node at ONE explicit level
   - Parent = nearest realized lower-level ancestor
   - Example:
     ```
     Row 1: "Healthcare" at level 0 → parent = NULL, last_seen[0] = Healthcare
     Row 2: "Behavioral Health" at level 1 → parent = last_seen[0], last_seen[1] = Behavioral Health
     Row 3: "Social Workers" at level 2 → parent = last_seen[1], last_seen[2] = Social Workers
     ```

3. **Updated Natural Key**: Includes parent_node_id
   - Old: `(taxonomy_id, node_type_id, customer_id, LOWER(value))`
   - New: `(taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value))`
   - Enables: "Associate" under both "Social Worker" and "Nurse" as distinct nodes

4. **Profession Column**: Separate from hierarchy
   - Excel: `Taxonomy Description (Profession)`
   - API: `layout.ProfessionColumn = "Profession Name"`
   - Stored on node but not used as hierarchical level

**Example**:
```
Input Excel (processed row-by-row):
  Row 1: "Healthcare" at level 0 (empty cells at levels 1-5)
  Row 2: "Behavioral Health" at level 1 (empty at 0, 2-5)
  Row 3: "Social Workers" at level 2 (empty at 0, 1, 3-5)
  Row 4: "Clinical Social Workers" at level 3 (empty at 0-2, 4-5)
  Row 5: "Advanced Clinical SW" at level 5 (empty at 0-4) - SKIPS level 4

Stored in Database:
  Level 0: Healthcare (parent = NULL)
  Level 1: Behavioral Health (parent = Healthcare)
  Level 2: Social Workers (parent = Behavioral Health)
  Level 3: Clinical Social Workers (parent = Social Workers)
  Level 5: Advanced Clinical SW (parent = Clinical Social Workers) - NO level 4 node needed
```

### Implementation Components (v1.0)

**Database Layer**:
- **Migration 001**: N/A node type with reserved ID (-1)
- **Migration 002**: 7 SQL helper functions for hierarchy operations
- **Migration 003**: Updated natural key constraint (includes parent_node_id) ⭐ **NEW**
  - Drops old unique constraint
  - Creates new constraint: `(taxonomy_id, node_type_id, customer_id, parent_node_id, LOWER(value))`
  - Adds indexes for parent queries and root nodes
  - Handles duplicate rows automatically

**TypeScript Classes (v1.0)**:
- **RollingAncestorResolver** ⭐ **NEW**: State management for parent resolution
  - `resolveParent(level, rowValues)` - finds nearest realized lower-level ancestor
  - `updateMemory(level, nodeId)` - updates last_seen[level] state
  - `isNAValue(value)` - checks for empty/N/A values
  - `reset()` - clears state for testing
- **Layout Parser (v1.0)**:
  - Parses `(node N)` syntax for explicit levels
  - Detects `(Profession)` column marker
  - Builds `NodeLevels` array with level-to-name mapping
  - Validates and sorts by level number
- **Filename Parser (v1.0)**:
  - New regex: `^(Master|Customer)\s+(-?\d+)\s+(-?\d+)(?:\s+.+)?(?:\.xlsx)?$`
  - Extracts taxonomy_type, customer_id, taxonomy_id
  - Sheet name used as taxonomy_name
- **Row Processor (v1.0)**:
  - Complete rewrite for single-node-per-row logic
  - Uses RollingAncestorResolver for parent resolution
  - Processes rows in file order
  - Supports multi-valued cells (creates siblings)

### Lambda Integration (v1.0)

**Ingestion Lambda (v1.0)**:
```typescript
// Initialize rolling ancestor resolver
const ancestorResolver = new RollingAncestorResolver(client);

// Process rows in file order
for (const srcRow of rows) {
  // Extract node level and value from row
  const nodeLevel = determineLevel(srcRow, layout);
  const nodeValue = extractNodeValue(srcRow, nodeLevel);

  // Resolve parent using rolling memory
  const rowValues = buildRowValuesMap(srcRow, layout);
  const parentId = ancestorResolver.resolveParent(nodeLevel.level, rowValues);

  // Create node with explicit level and resolved parent
  const nodeId = await upsertNode(client, loadType, {
    ...params,
    parent_node_id: parentId,
    level: nodeLevel.level
  });

  // Update rolling memory
  ancestorResolver.updateMemory(nodeLevel.level, nodeId);
}
```

**Mapping Lambda**:
```typescript
// Include hierarchy in AI prompts
const fullPath = await hierarchyQueries.getFullPath(nodeId);
const llmPrompt = hierarchyQueries.formatPathForLLM(fullPath);
// Result: "L0:Healthcare → L1:Behavioral Health → L2:Social Workers"

// Filter N/A from matching candidates
WHERE node_type_id != -1
```

**Translation Lambda**:
```typescript
// Return N/A-filtered display paths with explicit levels
const displayPath = await hierarchyQueries.getDisplayPath(nodeId);
// Result: "Healthcare → Behavioral Health → Social Workers"
```

### Dual Display Strategy

**For LLMs (include N/A with markers)**:
- Purpose: Provide structural context for semantic understanding
- Format: `L1:Healthcare → [SKIP]:N/A → L3:Nurse`
- Usage: AI matching prompts, semantic analysis

**For Users (exclude N/A completely)**:
- Purpose: Clean, professional display
- Format: `Healthcare → Nurse`
- Usage: API responses, UI, reports

### Key Benefits
✅ **Consistent Structure**: All hierarchies have complete parent-child chains
✅ **Idempotent**: Reuses existing N/A nodes, prevents duplicates
✅ **Performance**: Dedicated indexes for N/A filtering (`idx_nodes_exclude_na`)
✅ **Clean Display**: Users never see placeholder nodes
✅ **Better AI Matching**: LLM understands hierarchy structure

### Testing
```bash
# Verify installation
npm run test:na-nodes

# Check for N/A pollution (should return 0)
SELECT COUNT(*) FROM silver_taxonomies_nodes
WHERE node_type_id = -1 AND value LIKE '%N/A%';
```

**Documentation**:
- [Implementation Summary](./docs/NA_NODE_IMPLEMENTATION_SUMMARY.md)
- [Integration Examples](./docs/INTEGRATION_EXAMPLES.md)
- [Migration Guide](./scripts/migrations/README.md)

---

## Detailed Workflow Documentation

### Workflow 1: Mapping Creation (Left-to-Right) - Detailed

#### Purpose
Create and validate mappings between customer taxonomies/professions and the master Propelus taxonomy.

#### Input Data from Customers
Customers typically provide minimal flat data (NOT hierarchical taxonomies):
- **State** (e.g., "WA", "CA")
- **Client Profession Code** (e.g., "ARNP", "ACLS")
- **Client Profession Description** (e.g., "Advanced Registered Nurse Practitioner")
- **Issuing Authority** (optional, rarely provided)

#### Process Flow
```
Customer Data → Bronze Layer → Silver Layer Processing → Mapping Rules → Human Review → Gold Layer
```

#### Detailed Steps

##### 1. Data Ingestion (Bronze Layer)
- Raw data stored in `bronze_professions` or `bronze_taxonomies`
- Minimal transformation, preserves original format

##### 2. Data Processing (Silver Layer)
- Parse and structure the data
- Store in `silver_professions` with attributes
- Track unique attribute combinations in `silver_attribute_combinations`

##### 3. Apply Mapping Rules
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

##### 4. Confidence Scoring
- **100%**: Exact match or deterministic rule
- **80-99%**: High confidence (may auto-approve based on settings)
- **60-79%**: Medium confidence (requires human review)
- **<60%**: Low confidence (requires human intervention)

##### 5. Human-in-the-Loop Review
For mappings with confidence < threshold:
- Present multiple options with confidence scores
- Show context and similar mappings
- Human selects correct mapping or creates new one
- System learns from decisions

##### 6. Promotion to Gold Layer
- Approved mappings stored in `gold_taxonomies_mapping` or `gold_mapping_professions`
- Becomes available for translation workflow

#### Key Tables Used
- `bronze_professions` - Raw input data
- `silver_professions` - Structured profession data
- `silver_attribute_combinations` - Unique attribute patterns
- `silver_context_rules` - Disambiguation rules
- `silver_issuing_authorities` - Authority definitions
- `silver_mapping_professions` - Candidate mappings
- `gold_mapping_professions` - Approved mappings

---

### Workflow 2: Translation (Right-to-Left) - Detailed

#### Purpose
Translate profession codes between taxonomies using established mappings (real-time, deterministic).

#### Process Flow
```
API Request → Validate → Lookup Mappings → Apply Rules → Return Result(s)
```

#### API Contract

##### Request
```json
POST /api/v1/translate
{
  "source_taxonomy": "client_a",
  "target_taxonomy": "evercheck",
  "source_code": "ARNP",
  "attributes": {
    "state": "WA",
    "issuing_authority": "Washington State Nursing Commission"
  }
}
```

##### Response Scenarios

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

#### Translation Process

##### 1. Input Validation
- Verify source and target taxonomies exist
- Validate required attributes are present

##### 2. Determine Path
- **Path 1**: Direct mapping if exists (Customer A → Customer B)
- **Path 2**: Through master (Customer A → Master → Customer B)

##### 3. Apply Context Rules
- Check `silver_context_rules` for overrides
- Apply issuing authority rules
- Handle special cases (e.g., ARRT overrides state)

##### 4. Lookup Mappings
- Query Gold layer tables for approved mappings
- Filter by provided attributes
- Return all matches if multiple exist

##### 5. Return Results
- Single result if unique match
- Multiple results if ambiguous (client decides)
- Empty result if no mapping exists

#### Key Characteristics
- **No Human Intervention**: Fully automated
- **Deterministic**: Same input always produces same output
- **Real-time**: Sub-second response times
- **Flexible**: Can return multiple matches, letting client decide

#### Tables Used
- `gold_taxonomies_mapping` - Approved taxonomy mappings
- `gold_mapping_professions` - Approved profession mappings
- `silver_context_rules` - Context and override rules
- `silver_issuing_authorities` - Authority information

---

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

---

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

---

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

---

## Workflow Success Metrics

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

---

### Three-Layer Data Architecture

#### 1. Bronze Layer (Raw Data)
- **Purpose**: Store raw profession lists exactly as received
- **Primary Table**: `bronze_professions` (main customer data entry point)
- **Secondary**: `bronze_taxonomies` (master taxonomy updates only)
- **New Fields**:
  - `file_url`: Optional file path (file uploads)
  - `request_id`: Unique identifier for async tracking
- **Load Tracking**: `bronze_load_details` for comprehensive audit

#### 2. Silver Layer (Mapping & Rules)
- **Purpose**: Map customer professions directly to master taxonomy nodes
- **Master Taxonomy Only**: Single source of truth maintained by Propelus
- **Mapping Tables**:
  - `silver_mapping_professions`: Profession → Master taxonomy mappings
  - `silver_mapping_professions_rules`: Deterministic + AI rules
- **Versioning**: Support for remapping with version tracking
- **User Tracking**: Who created/approved each mapping

#### 3. Gold Layer (Production)
- **Purpose**: Approved mappings for production APIs
- **Tables**:
  - `gold_mapping_professions`: Production-ready profession mappings
- **Versioned**: Track mapping versions for rollback capability

## Lambda Functions Architecture

### 1. Ingestion and Cleanup Lambda
**Purpose**: Process raw data from Bronze to Silver layer
**Process**:
1. Read from Bronze tables
2. Parse JSON data
3. Extract and normalize:
   - Taxonomy hierarchies
   - Node types and relationships
   - Profession names and attributes
4. Load into Silver layer tables
5. Handle data quality issues

### 2. Silver Processing Lambda
**Purpose**: Transform Bronze data into structured Silver taxonomies
**Features**:
- NLP-based text processing and normalization
- Taxonomy hierarchy construction
- Attribute extraction and validation
- State code mapping (50 US states)
**Process**:
1. Read Bronze layer data
2. Parse and structure profession/taxonomy data
3. Extract attributes (state, license type, etc.)
4. Build hierarchical relationships
5. Store in Silver layer tables
6. Trigger mapping rules processing

### 3. Mapping Rules Lambda
**Purpose**: Apply mapping rules with multiple matching strategies
**Features**:
- **Exact Matcher**: Direct string matching (case-insensitive) → 100% confidence
- **Fuzzy Matcher**: Levenshtein distance similarity → variable confidence
- **AI Semantic Matcher**: AWS Bedrock Claude for complex cases → 50-99% confidence
- Priority-based execution (stops at first successful match)
- Confidence scoring for each match type
**Process**:
1. Load unmapped nodes from Silver layer
2. Try exact match first (100% confidence)
3. Try fuzzy match if no exact match (70-90% confidence)
4. Try AI semantic match as last resort (50-99% confidence)
5. Store mapping results in Silver mapping tables
6. Flag low-confidence matches (<70%) for human review

### 4. Translation Lambda
**Purpose**: Real-time translation service via API
**Features**:
- Deterministic lookup in Gold layer mappings
- Redis caching for performance
- Support for multiple target taxonomies
- Returns multiple matches if ambiguous
**Process**:
1. Receive translation request via API
2. Look up approved mappings in Gold layer
3. Apply context rules (issuing authority, state, etc.)
4. Return matched profession(s) with confidence
5. Cache results in Redis for repeat queries

## Data Model Details

### Taxonomy Structure
```
Master Taxonomy (Propelus SSOT, ID: -1)
    ↓ (Mapping via rules + AI)
Customer Taxonomies (Hierarchical, multiple per customer)
    ↓ (Mapping via rules)
Professions (Non-hierarchical data sets with attributes)
```

### Key Entities

#### Taxonomies
- **Master Taxonomy**: Propelus SSOT (taxonomy_id: -1, customer_id: -1)
- **Customer Taxonomies**: Client-specific hierarchies
- **Attributes**: Name, type (master/customer), status (active/inactive)
- **Dual Mapping Paths**:
  1. Master ↔ Customer taxonomy (bidirectional)
  2. Customer profession → Customer taxonomy (unidirectional)

#### Nodes
- **Hierarchy Levels**: Industry → Profession Group → Broad Occupation → Detailed Occupation → Specialty → Profession
- **Node Types**: Dynamic per taxonomy
- **Parent-Child Relationships**: Maintained for hierarchy

#### Professions
- **Core Data**: Name, ID, status
- **Attributes**:
  - States (e.g., CA, FL, TX)
  - Abbreviations (e.g., RN, NP)
  - Occupation statuses (permanent, temporary)
  - License requirements
  - Custom attributes per customer

#### Mapping Rules
- **Types**: Regex, exact match, fuzzy match, AI-based
- **Priority System**: Rules execute in priority order
- **Confidence Levels**:
  - 100%: Deterministic match (auto-approve)
  - 90-99%: High confidence (configurable auto-approve)
  - 70-89%: Medium confidence (human review)
  - <70%: Low confidence (requires human intervention)

## Confidence Scoring & Human Review

### Confidence Thresholds
- **Auto-Approval**: ≥90% (configurable)
- **Review Required**: 70-89%
- **Manual Mapping**: <70%

### Human-in-the-Loop Workflow
1. System presents multiple mapping options
2. Shows confidence scores for each
3. Human reviews context and alternatives
4. Selects correct mapping or creates new
5. System learns from decisions
6. Updates gold layer with approved mappings

### Status Management
- **Active**: Approved and in use
- **Pending**: Awaiting human review
- **Rejected**: Declined mappings
- **Inactive**: Deprecated mappings

## API Endpoints

### 1. Taxonomy Query API
```
GET /api/v1/taxonomies
GET /api/v1/taxonomies/{id}/nodes
POST /api/v1/taxonomies/search
```

### 2. Translation API
```
POST /api/v1/translate
{
  "input_text": "RN in ICU",
  "context": {"state": "FL"},
  "options": {
    "include_alternatives": true,
    "min_confidence": 0.7
  }
}
```

### 3. Professional Title Check API
```
POST /api/v1/professions/validate
GET /api/v1/professions/mappings
```

### 4. Admin APIs
```
GET /api/v1/admin/review-queue
POST /api/v1/admin/approve-mapping
POST /api/v1/admin/reject-mapping
PUT /api/v1/admin/create-mapping
```

## Key Insights from Customer Meeting (Sept 24)

### Customer Data Reality
- **Customers rarely provide hierarchical taxonomies**
- Typical input is flat lists with 3-4 fields:
  - State (e.g., "WA")
  - Client profession code (e.g., "ARNP")
  - Client profession description
  - Issuing authority (rarely provided)

### Two Distinct Workflows
1. **Mapping Creation (Left-to-Right)**:
   - Requires human-in-the-loop for low confidence
   - Builds the mapping database
   - Uses Bronze → Silver → Gold flow

2. **Translation Service (Right-to-Left)**:
   - Fully deterministic, no human intervention
   - Real-time API responses
   - Can return multiple matches if attributes insufficient

### Critical Requirements
- **Issuing Authority Context**: Essential for proper mapping
  - State-based (static list)
  - National certifications (dynamic, evolving)
  - Some override state (e.g., ARRT is always national)

- **Attribute Combinations**: Must track each unique combination
  - "WA + ARNP" stored separately from "CA + ARNP"
  - Helps disambiguate future mappings

- **Context Rules**: Need rules for common abbreviations
  - ACLS → American Heart Association
  - ARRT → Always national certification
  - RQI → Context-dependent

## Key Insights from Sept 25 Meeting

### Data Model Refinements
- **Attributes Structure**: Edwin suggested attribute types catalog separate from values
- **Bronze Traceability**: Track data sources (API calls, files) with source_id
- **Flexible Mapping**: Changed "master_node_id" to "target_node_id" for customer-to-customer mappings
- **Data Lineage**: Need complete traceability from Bronze → Silver → Gold

### Technical Decisions
- **Database**: Staying with Aurora PostgreSQL per data team decision
- **GraphQL Layer**: Data team has GraphQL API layer on top of PostgreSQL
- **Observability**: CloudWatch for logs, then filtered to CloudWatch Insights
- **Master Taxonomy**: Manual creation process initially

### Processing Requirements
- **Source Tracking**: Store file names, API endpoints, request IDs
- **Processing Stages**: Track each stage (ingestion, processing, mapping, review, promotion)
- **Attribute Types**: Catalog of standard attributes (state, abbreviation, license_type)
- **Version Control**: Track master taxonomy versions for changes

## Use Cases (Updated September 2025)

### Use Case 1: Profession Mapping (Primary)
**Scenario**: Customer provides profession list, needs mapping to master taxonomy
**Flow**:
1. Customer sends API request with profession list (or uploads file)
2. System ingests to Bronze layer with request_id
3. Process through Silver layer - map directly to master taxonomy
4. Apply deterministic rules first, then AI if needed
5. Low confidence (<70%) flagged for human review
6. Approved mappings promoted to Gold layer
7. Optional: Webhook callback when processing complete

**Example Input**:
```json
{
  "request_id": "req_12345",
  "customer_id": 123,
  "professions": [
    {
      "code": "RN",
      "description": "Registered Nurse",
      "state": "CA",
      "issuing_authority": "California Board of Nursing"
    }
  ]
}
```

### Use Case 2: Translation Query (Right-to-Left)
**Scenario**: Backend service needs to translate customer profession to standardized format
**Flow**:
1. Service sends translation request: profession code + attributes
2. System looks up in Gold layer mappings
3. Returns master taxonomy match(es) with confidence scores
4. Fully deterministic - no AI, no human review
5. Real-time response (<100ms)

**Example Query**:
```json
{
  "source_taxonomy": "kaiser_permanente",
  "source_code": "RN",
  "attributes": {"state": "CA"}
}
```

### Use Case 3: Master Taxonomy Update & Remapping
**Scenario**: Propelus updates master taxonomy, needs to remap existing professions
**Flow**:
1. Propelus team updates master taxonomy structure
2. System increments taxonomy version
3. Logs changes in version history table
4. Optional: Trigger remapping of stored profession mappings
5. Reprocess historical data through updated taxonomy
6. Generate new mapping versions
7. Review changes and promote to Gold
8. Old versions marked inactive but retained for audit

### Use Case 4: Bulk Profession Onboarding
**Scenario**: New customer onboarding with 10,000+ professions
**Flow**:
1. Customer uploads file or sends bulk API request
2. System creates load record with request_id
3. Queue-based processing in batches
4. High-confidence mappings auto-approved to Gold
5. Low-confidence cases go to review queue
6. Human reviews ambiguous cases
7. Webhook notification when processing complete
8. Customer can query status via request_id

## Implementation Timeline

### Phase 1: Foundation (Weeks 1-3)
- Design data model
- Set up Bronze/Silver/Gold layers
- Create database schema

### Phase 2: Core Lambda Functions (Weeks 4-7)
- Implement ingestion Lambda
- Build deterministic mapping engine
- Create rule management system

### Phase 3: AI Integration (Weeks 8-10)
- Integrate AWS Bedrock
- Implement semantic search
- Build confidence scoring

### Phase 4: Human Review & Admin (Weeks 11-12)
- Create review queue
- Build admin UI
- Implement approval workflow

### Phase 5: Testing & Deployment (Weeks 13-14)
- End-to-end testing
- Performance optimization
- Production deployment

## Technical Stack

### Data Layer
- **Database**: PostgreSQL (AWS Aurora)
- **Analytics**: Snowflake
- **Cache**: Redis
- **Data Pipeline**: AWS Lambda

### AI/ML
- **LLM**: AWS Bedrock (Claude 3 Sonnet) - used as fallback for semantic matching only

### APIs & Services
- **API Framework**: FastAPI
- **Admin UI**: Streamlit
- **Monitoring**: CloudWatch
- **Infrastructure**: Terraform

## Performance Requirements

### Response Times
- Deterministic matching: <100ms
- AI-powered matching: <2s
- Bulk processing: 10,000 records/minute

### Accuracy Targets
- Deterministic rules: 100% accuracy
- AI matching: >85% accuracy
- Overall system: >95% with human review

## Security & Compliance

### Data Security
- Encryption at rest and in transit
- PII data masking
- Audit logging for all changes
- Role-based access control

### Compliance
- HIPAA compliant infrastructure
- SOC 2 certification ready
- GDPR compliance for EU customers

## Monitoring & Metrics

### Key Metrics
- Mapping accuracy rate
- Average confidence score
- Human review queue size
- Processing latency
- API response times

### Dashboards
- Real-time processing status
- Confidence score distribution
- Human review metrics
- System health indicators

## Support & Maintenance

### Regular Tasks
- Rule optimization
- AI model fine-tuning
- Confidence threshold adjustment
- Performance monitoring
- Data quality checks

### Documentation
- API documentation (OpenAPI/Swagger)
- Admin guide
- Integration guide
- Troubleshooting guide

## Future Enhancements

### Planned Features
- Multi-language support
- Real-time streaming API
- Advanced analytics dashboard
- Mobile admin app
- Automated rule learning from human decisions

### Scalability Plans
- Horizontal scaling of Lambda functions
- Multi-region deployment
- Caching optimization
- Database sharding for large customers