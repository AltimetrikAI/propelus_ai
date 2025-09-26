# Propelus Data Model Documentation

## Overview
This document provides detailed specifications for the three-layer data architecture (Bronze, Silver, Gold) used in the Propelus Taxonomy Framework.

## Data Architecture Layers

### Bronze Layer (Raw Data Ingestion)
The Bronze layer serves as the landing zone for all raw data from external sources. Data is stored in its original format with minimal transformation.

### Silver Layer (Structured & Cleansed Data)
The Silver layer contains cleaned, validated, and structured data. This is where data quality rules are applied and relationships are established.

### Gold Layer (Production-Ready Data)
The Gold layer contains aggregated, business-ready data optimized for consumption by applications and analytics.

## Bronze Layer Tables

### bronze_taxonomies
**Purpose**: Raw ingestion of hierarchical taxonomy data per customer
| Column | Type | Description |
|--------|------|-------------|
| customer_id | INTEGER | Identifier of the customer providing the taxonomy from API |
| row_json | JSON | JSON containing one single row of taxonomy data |
| load_date | TIMESTAMP | Timestamp when the row was loaded into table |
| type | VARCHAR(20) | Type of ingestion – 'new' or 'updated' |

### bronze_professions
**Purpose**: Raw ingestion of non-hierarchical profession data with attributes per customer
| Column | Type | Description |
|--------|------|-------------|
| customer_id | INTEGER | Identifier of the customer providing profession data |
| row_json | JSON | JSON containing one single row of profession data with attributes |
| load_date | TIMESTAMP | Timestamp when the row was loaded into table |
| type | VARCHAR(20) | Type of ingestion – 'new' or 'updated' |

## Silver Layer Tables

### Core Taxonomy Tables

#### silver_taxonomies
**Purpose**: Table with basic data of hierarchical taxonomies
| Column | Type | Description |
|--------|------|-------------|
| taxonomy_id | SERIAL | Primary surrogate key - ID of the taxonomy |
| customer_id | INTEGER | Customer ID (-1 for master Propelus taxonomy) |
| name | VARCHAR(255) | Name of the taxonomy |
| type | VARCHAR(20) | 'master' for Propelus taxonomy or 'customer' |
| status | VARCHAR(20) | 'active' or 'inactive' |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_taxonomies_nodes_types
**Purpose**: Defines the types of nodes used in hierarchical taxonomies
| Column | Type | Description |
|--------|------|-------------|
| node_type_id | SERIAL | Primary surrogate key - ID for the node type |
| name | VARCHAR(100) | Name of the node type (e.g., 'Industry', 'Profession') |
| status | VARCHAR(20) | 'active' or 'inactive' |
| level | INTEGER | Hierarchy level (1 for root) |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

**Standard Node Types**:
1. Industry (Level 1)
2. Profession Group (Level 2)
3. Broad Occupation (Level 3)
4. Detailed Occupation (Level 4)
5. Occupation Specialty (Level 5)
6. Profession (Level 6)

#### silver_taxonomies_nodes
**Purpose**: Stores actual hierarchy nodes within taxonomies
| Column | Type | Description |
|--------|------|-------------|
| node_id | SERIAL | Primary surrogate key - ID of the node |
| node_type_id | INTEGER | Foreign key to silver_taxonomies_nodes_types |
| taxonomy_id | INTEGER | Foreign key to silver_taxonomies |
| parent_node_id | INTEGER | Foreign key to parent node (NULL for top level) |
| value | TEXT | Text value of the node (e.g., 'Healthcare', 'Advanced Psychiatric Nurse') |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_taxonomies_nodes_attributes
**Purpose**: Stores attributes assigned to taxonomy nodes
| Column | Type | Description |
|--------|------|-------------|
| attribute_id | SERIAL | Primary surrogate key - ID of the attribute |
| node_id | INTEGER | Foreign key to silver_taxonomies_nodes |
| name | VARCHAR(100) | Attribute name (e.g., 'profession_abbreviation') |
| value | TEXT | Attribute value (e.g., 'APRN') |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

### Taxonomy Mapping Tables

#### silver_mapping_taxonomies_rules_types
**Purpose**: Defines types of mapping rules for hierarchical taxonomies
| Column | Type | Description |
|--------|------|-------------|
| mapping_rule_type_id | SERIAL | Primary surrogate key - ID for the rule type |
| name | VARCHAR(100) | Rule type name (e.g., 'regex', 'AI') |
| command | VARCHAR(100) | Command executed by rule |
| ai_mapping_flag | BOOLEAN | TRUE if this rule uses AI-based mappings |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_mapping_taxonomies_rules
**Purpose**: Stores automated mapping rules for taxonomy-to-taxonomy mapping
| Column | Type | Description |
|--------|------|-------------|
| mapping_rule_id | SERIAL | Primary surrogate key - rule ID |
| mapping_rule_type_id | INTEGER | Foreign key to rule types |
| name | VARCHAR(255) | Rule name indicating the algorithm |
| enabled | BOOLEAN | Active/inactive flag |
| pattern | TEXT | Pattern used in executed command |
| attributes | JSONB | Attributes used with executed command |
| flags | JSONB | Flags used with executed command |
| action | TEXT | Action that command performs |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_mapping_taxonomies_rules_assignment
**Purpose**: Assigns mapping rules to node types and sets up priorities
| Column | Type | Description |
|--------|------|-------------|
| mapping_rule_assignment_id | SERIAL | Primary surrogate key - assignment ID |
| mapping_rule_id | INTEGER | Foreign key to mapping rules |
| master_node_type_id | INTEGER | Node type in master taxonomy |
| node_type_id | INTEGER | Node type in customer taxonomy |
| priority | INTEGER | Priority of rule execution |
| enabled | BOOLEAN | Active/inactive flag |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_mapping_taxonomies
**Purpose**: Holds mapping results after applying mapping rules to taxonomies
| Column | Type | Description |
|--------|------|-------------|
| mapping_id | SERIAL | Primary surrogate key – mapping ID |
| mapping_rule_id | INTEGER | Rule that resolved the mapping |
| target_node_id | INTEGER | Target node (can be master or another customer taxonomy) |
| node_id | INTEGER | Source node in customer taxonomy |
| confidence | DECIMAL(5,2) | Confidence score (0-100) |
| status | VARCHAR(20) | 'active' or 'inactive' |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

### Profession Tables (Non-Hierarchical)

#### silver_professions
**Purpose**: Table with basic data of non-hierarchical profession data sets
| Column | Type | Description |
|--------|------|-------------|
| profession_id | SERIAL | Primary surrogate key – profession ID |
| customer_id | INTEGER | Customer providing the profession data set |
| name | VARCHAR(500) | Profession name |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_professions_attributes
**Purpose**: Stores attributes assigned to professions
| Column | Type | Description |
|--------|------|-------------|
| attribute_id | SERIAL | Primary surrogate key – attribute ID |
| profession_id | INTEGER | Foreign key to silver_professions |
| name | VARCHAR(100) | Attribute name (e.g., 'USA_state') |
| value | TEXT | Attribute value (e.g., 'CA') |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

### Profession Mapping Tables

#### silver_mapping_professions_rules_types
**Purpose**: Defines types of mapping rules for non-hierarchical professions
| Column | Type | Description |
|--------|------|-------------|
| mapping_rule_type_id | SERIAL | Primary surrogate key - ID for the rule type |
| name | VARCHAR(100) | Rule type name |
| command | VARCHAR(100) | Command executed by rule |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_mapping_professions_rules
**Purpose**: Stores automated mapping rules for profession-to-taxonomy mapping
| Column | Type | Description |
|--------|------|-------------|
| mapping_rule_id | SERIAL | Primary surrogate key - rule ID |
| mapping_rule_type_id | INTEGER | Foreign key to rule types |
| name | VARCHAR(255) | Rule name |
| enabled | BOOLEAN | Active/inactive flag |
| pattern | TEXT | Pattern used in executed command |
| attributes | JSONB | Attributes used with executed command |
| flags | JSONB | Flags used with executed command |
| action | TEXT | Action that command performs |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_mapping_professions_rules_assignment
**Purpose**: Assigns mapping rules to customer taxonomies node types
| Column | Type | Description |
|--------|------|-------------|
| mapping_rule_assignment_id | SERIAL | Primary surrogate key - assignment ID |
| mapping_rule_id | INTEGER | Foreign key to profession rules |
| node_type_id | INTEGER | Node type in customer taxonomy |
| priority | INTEGER | Priority of rule execution |
| enabled | BOOLEAN | Active/inactive flag |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

#### silver_mapping_professions
**Purpose**: Holds mapping results for profession-to-taxonomy mappings
| Column | Type | Description |
|--------|------|-------------|
| mapping_id | SERIAL | Primary surrogate key – mapping ID |
| mapping_rule_id | INTEGER | Rule that resolved the mapping |
| node_id | INTEGER | Node in customer taxonomy |
| profession_id | INTEGER | Profession in customer data sets |
| status | VARCHAR(20) | 'active' or 'inactive' |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

### Issuing Authorities and Context Tables

#### silver_issuing_authorities
**Purpose**: Stores all issuing authorities including state boards and national certification bodies
| Column | Type | Description |
|--------|------|-------------|
| authority_id | SERIAL | Primary key |
| name | VARCHAR(255) | Authority name |
| type | VARCHAR(50) | 'state', 'national', or 'federal' |
| state_code | VARCHAR(2) | State code (NULL for national/federal) |
| abbreviation | VARCHAR(50) | Common abbreviation |
| priority | INTEGER | Lower number = higher priority |
| is_active | BOOLEAN | Active status |
| created_at | TIMESTAMP | Creation timestamp |
| last_updated_at | TIMESTAMP | Last update timestamp |

#### silver_context_rules
**Purpose**: Defines context rules for disambiguating abbreviations and handling special cases
| Column | Type | Description |
|--------|------|-------------|
| rule_id | SERIAL | Primary key |
| rule_name | VARCHAR(255) | Descriptive rule name |
| rule_type | VARCHAR(50) | 'abbreviation', 'override', 'disambiguation', 'priority' |
| pattern | TEXT | Regex or exact match pattern |
| context_key | VARCHAR(100) | Key like 'ACLS', 'ARRT' |
| context_value | TEXT | Value like 'American Heart Association' |
| priority | INTEGER | Execution order |
| override_state | BOOLEAN | TRUE if overrides state attribute |
| notes | TEXT | Additional context |

#### silver_attribute_combinations
**Purpose**: Tracks unique combinations of attributes seen during mapping
| Column | Type | Description |
|--------|------|-------------|
| combination_id | SERIAL | Primary key |
| customer_id | INTEGER | Customer identifier |
| state_code | VARCHAR(2) | State if provided |
| profession_code | VARCHAR(100) | Customer's profession code |
| profession_description | TEXT | Description text |
| additional_attributes | JSONB | Other attributes |
| combination_hash | VARCHAR(64) | MD5 hash for quick lookup |
| occurrence_count | INTEGER | Times this combination seen |
| mapping_status | VARCHAR(20) | 'mapped', 'pending', 'failed', 'ambiguous' |
| mapping_confidence | DECIMAL(5,2) | Confidence if mapped |

#### silver_translation_patterns
**Purpose**: Stores patterns of translation requests for analysis
| Column | Type | Description |
|--------|------|-------------|
| pattern_id | SERIAL | Primary key |
| source_taxonomy_id | INTEGER | Source taxonomy |
| target_taxonomy_id | INTEGER | Target taxonomy |
| source_code | VARCHAR(100) | Code being translated |
| source_attributes | JSONB | Attributes provided |
| result_count | INTEGER | Number of matches |
| is_ambiguous | BOOLEAN | Multiple matches returned |
| request_count | INTEGER | Times pattern seen |

### Audit Tables

#### silver_taxonomies_log
**Purpose**: Keeps an audit trail of changes applied to silver_taxonomies table
| Column | Type | Description |
|--------|------|-------------|
| taxonomy_id | INTEGER | Primary key of affected row |
| old_row | JSONB | Snapshot before change (NULL for insert) |
| new_row | JSONB | Snapshot after change |
| operation_type | VARCHAR(20) | 'insert', 'update', or 'delete' |
| operation_date | TIMESTAMP | When the operation occurred |
| user_name | VARCHAR(255) | User that performed the operation |

## Gold Layer Tables

### gold_taxonomies_mapping
**Purpose**: Final approved mappings between taxonomies
| Column | Type | Description |
|--------|------|-------------|
| mapping_id | INTEGER | Primary key from silver_mapping_taxonomies |
| target_node_id | INTEGER | Target node in target taxonomy |
| node_id | INTEGER | Source node in customer taxonomy |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

### gold_mapping_professions
**Purpose**: Final mappings between taxonomy nodes and professions
| Column | Type | Description |
|--------|------|-------------|
| mapping_id | INTEGER | Primary key from silver_mapping_professions |
| node_id | INTEGER | Node in customer taxonomy |
| profession_id | INTEGER | Profession in customer data sets |
| created_at | TIMESTAMP | When the row was created |
| last_updated_at | TIMESTAMP | When the row was last updated |

## Data Flow

### Taxonomy Ingestion Flow
1. **Bronze Layer**: Raw taxonomy JSON data loaded from customer API
2. **Silver Layer**:
   - Parse JSON to create taxonomy record
   - Extract and create node types
   - Build hierarchical node structure
   - Add node attributes
3. **Mapping Process**:
   - Apply deterministic rules (regex, exact match)
   - Use AI for complex mappings if confidence < threshold
   - Flag low-confidence mappings for human review
4. **Gold Layer**: Approved mappings promoted to production

### Profession Ingestion Flow
1. **Bronze Layer**: Raw profession data with attributes loaded
2. **Silver Layer**:
   - Parse and create profession records
   - Extract attributes (state, license type, etc.)
   - Deduplicate profession names
3. **Mapping Process**:
   - Map professions to customer taxonomy nodes
   - Apply rule-based mappings
   - Report unmapped professions
4. **Gold Layer**: Finalized profession mappings

## Mapping Rules Execution

### Rule Priority System
Rules are executed in priority order (1 = highest):
1. Exact match rules (Priority 1-10)
2. Regex pattern rules (Priority 11-50)
3. Fuzzy match rules (Priority 51-100)
4. AI-based semantic rules (Priority 101+)

### Confidence Scoring
- **100%**: Exact match or deterministic rule
- **80-99%**: High-confidence fuzzy or pattern match
- **60-79%**: Medium confidence, may need review
- **<60%**: Low confidence, requires human review

## Indexing Strategy

### Performance Indexes
```sql
-- Taxonomy hierarchy navigation
CREATE INDEX idx_nodes_taxonomy_level ON silver_taxonomies_nodes(taxonomy_id, node_type_id);
CREATE INDEX idx_nodes_parent ON silver_taxonomies_nodes(parent_node_id);

-- Mapping lookups
CREATE INDEX idx_mapping_status ON silver_mapping_taxonomies(status, confidence);
CREATE INDEX idx_mapping_nodes ON silver_mapping_taxonomies(master_node_id, node_id);

-- Attribute searches
CREATE INDEX idx_attr_node ON silver_taxonomies_nodes_attributes(node_id, name);
```

## Data Retention Policy

### Bronze Layer
- Retention: 90 days for debugging
- Archive: Move to cold storage after 90 days

### Silver Layer
- Active mappings: Retained indefinitely
- Inactive/rejected: Archive after 1 year

### Gold Layer
- All data retained indefinitely
- Partitioned by year for performance

## Migration History

### Migration 001: Initial Schema
- Created initial profession taxonomy structure
- Implemented translation system
- Added audit logging

### Migration 002: Bronze/Silver/Gold Architecture
- Restructured to three-layer architecture
- Separated taxonomies and professions
- Added comprehensive mapping rule system
- Implemented dual mapping paths:
  - Master taxonomy ↔ Customer taxonomy
  - Customer profession → Customer taxonomy

### Migration 003: Issuing Authorities and Context (Sept 24 Meeting)
- Added issuing authorities management
- Implemented context rules for disambiguation
- Added attribute combination tracking
- Created translation pattern analysis
- Enhanced mappings with authority support