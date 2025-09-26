# Lambda Functions Architecture

## Overview
The Propelus Taxonomy Framework uses four main AWS Lambda functions to process data through the Bronze → Silver → Gold pipeline. Each Lambda has specific responsibilities and operates on different data layers.

## Lambda Function Details

## 1. Ingestion and Cleanup Lambda

### Purpose
Process raw data from external sources into structured format

### Input
- Customer taxonomy files (JSON/CSV/Excel)
- Professional data files
- API payloads

### Process Flow
```
1. Read from Bronze tables (bronze_taxonomies, bronze_professions)
2. Parse and validate JSON/CSV data
3. Extract taxonomy structure:
   - Identify node types (industry, profession group, etc.)
   - Build hierarchy relationships
   - Extract node attributes
4. Normalize profession data:
   - Clean profession names
   - Extract attributes (state, license, etc.)
5. Load into Silver tables:
   - silver_taxonomies
   - silver_taxonomy_node_types
   - silver_taxonomy_nodes
   - silver_taxonomy_nodes_attributes
   - silver_professions
   - silver_professions_attributes
```

### Data Transformations
- **Text Normalization**: Lowercase, trim spaces, remove special characters
- **Abbreviation Expansion**: RN → Registered Nurse
- **Hierarchy Building**: Create parent-child relationships
- **Attribute Extraction**: Separate core data from attributes

### Output Tables
- `silver_taxonomies`: Taxonomy metadata
- `silver_taxonomy_nodes`: All nodes with hierarchy
- `silver_professions`: Cleaned profession names

### Error Handling
- Log malformed data to error table
- Continue processing valid records
- Generate data quality report

### Example Code Structure
```python
def lambda_handler(event, context):
    # 1. Read from bronze layer
    bronze_data = read_bronze_taxonomies()

    # 2. Parse and clean
    cleaned_data = parse_taxonomy_data(bronze_data)

    # 3. Build hierarchy
    hierarchy = build_node_hierarchy(cleaned_data)

    # 4. Extract attributes
    attributes = extract_node_attributes(cleaned_data)

    # 5. Write to silver layer
    write_to_silver_taxonomies(hierarchy)
    write_to_silver_attributes(attributes)

    return {
        'statusCode': 200,
        'processed_records': len(cleaned_data),
        'errors': error_count
    }
```

## 2. Translation Constant Command Logic Lambda

### Purpose
Apply deterministic rules for high-confidence mapping

### Input
- Silver layer taxonomy and profession data
- Mapping rules configuration
- Priority assignments

### Process Flow
```
1. Load active mapping rules from silver_mapping_rules
2. Sort rules by priority
3. For each unmapped item:
   a. Apply rules in priority order
   b. Stop at first match
   c. Record mapping with 100% confidence
4. Auto-map child nodes when parent matches
5. Store results in silver_mapping tables
```

### Rule Types

#### Regex Comparison Rule
```python
def regex_rule(input_text, pattern):
    # Remove text between dashes
    # Example: "Advanced-Practice-Nurse" → "Advanced Nurse"
    cleaned = re.sub(r'-.*?-', ' ', input_text)
    return cleaned.lower() == pattern.lower()
```

#### Exact Match Rule
```python
def exact_match_rule(input_text, target):
    # Case-insensitive, space-normalized comparison
    return normalize(input_text) == normalize(target)
```

### Priority System
1. **Priority 1**: Exact match (ignoring case/spaces)
2. **Priority 2**: Regex patterns
3. **Priority 3**: Fuzzy matching
4. **Priority 4**: Abbreviation expansion

### Auto-Mapping Logic
When a parent node is mapped, automatically map all children:
```python
if parent_mapped:
    for child in get_children(parent_node):
        map_to_corresponding_child(child, target_parent)
```

### Output
- Mappings with 100% confidence
- Status: "active" (no review needed)
- Update silver_mapping_taxonomies table

## 3. Translation LLM Logic Lambda

### Purpose
Use AI for complex mappings that rules can't handle

### Input
- Unmapped items from constant command lambda
- Context data (state, specialty, etc.)
- Confidence threshold settings

### Process Flow
```
1. Generate embeddings for unmapped items
2. Search vector store for similar items
3. Use LLM for intelligent matching:
   a. Provide context and candidates
   b. Get multiple suggestions with reasoning
   c. Calculate confidence scores
4. Handle results based on confidence:
   - ≥90%: Auto-approve
   - 70-89%: Flag for review
   - <70%: Require manual mapping
5. Store all suggestions for human review
```

### AI Integration
```python
def ai_mapping(input_text, candidates):
    prompt = f"""
    Map this profession: {input_text}

    Candidates:
    {candidates}

    Consider:
    - Semantic similarity
    - Common abbreviations
    - Regional variations

    Return top 3 matches with confidence scores.
    """

    response = bedrock_client.invoke(
        model='claude-3-sonnet',
        prompt=prompt
    )

    return parse_ai_response(response)
```

### Confidence Calculation
```python
def calculate_confidence(ai_score, semantic_similarity, context_match):
    weights = {
        'ai_score': 0.5,
        'semantic': 0.3,
        'context': 0.2
    }

    final_score = (
        ai_score * weights['ai_score'] +
        semantic_similarity * weights['semantic'] +
        context_match * weights['context']
    )

    return min(final_score * 100, 99)  # Cap at 99% for AI
```

### Multiple Results Handling
- Store all AI suggestions
- Mark status as "pending"
- Include reasoning for each suggestion
- Await human review for selection

### Output Format
```json
{
  "mappings": [
    {
      "master_node_id": 6,
      "customer_node_id": 12,
      "confidence": 85,
      "reasoning": "Strong semantic match, same abbreviation",
      "status": "pending"
    },
    {
      "master_node_id": 7,
      "customer_node_id": 12,
      "confidence": 60,
      "reasoning": "Partial match, different specialty",
      "status": "pending"
    }
  ]
}
```

## 4. Check Professional Title Lambda

### Purpose
Validate individual profession titles against taxonomies

### Input
- Profession title from customer
- Associated attributes (state, license type)
- Customer taxonomy reference

### Process Flow
```
1. Load profession and attributes from silver_professions
2. Apply static mapping rules only (no AI)
3. Check against customer taxonomy nodes
4. Handle multiple matches if found
5. Report unmapped professions
```

### Key Differences
- **No AI Usage**: Only deterministic rules
- **Profession-Focused**: Works with individual titles, not hierarchies
- **Attribute Handling**: State, license type as separate attributes

### Mapping Logic
```python
def check_profession(profession_name, state, customer_id):
    # 1. Try exact match
    exact = find_exact_match(profession_name, customer_id)
    if exact:
        return exact

    # 2. Try with abbreviation expansion
    expanded = expand_abbreviations(profession_name)
    match = find_match(expanded, customer_id)
    if match:
        return match

    # 3. Try removing prefixes/suffixes
    cleaned = remove_prefixes(profession_name)
    match = find_match(cleaned, customer_id)
    if match:
        return match

    # 4. Report as unmapped
    return None
```

### Output
- Direct profession-to-node mappings
- List of unmapped professions for manual review
- No confidence scores (binary match/no-match)

## Lambda Configuration

### Environment Variables
```yaml
# Common
DATABASE_URL: postgresql://user:pass@host/db
LOG_LEVEL: INFO

# Ingestion Lambda
BRONZE_BUCKET: s3://propelus-bronze-data
VALIDATION_RULES: strict

# Translation Constant Lambda
RULE_TIMEOUT: 30
MAX_RULES: 100

# Translation LLM Lambda
BEDROCK_REGION: us-east-1
MODEL_ID: claude-3-sonnet
CONFIDENCE_THRESHOLD: 70
EMBEDDING_MODEL: titan-embed

# Check Professional Lambda
CUSTOMER_TAXONOMY_CACHE: 3600
```

### Resource Requirements
| Lambda | Memory | Timeout | Concurrency |
|--------|---------|---------|-------------|
| Ingestion | 1024 MB | 5 min | 10 |
| Constant Command | 512 MB | 2 min | 50 |
| LLM Logic | 2048 MB | 30 sec | 20 |
| Check Professional | 512 MB | 1 min | 100 |

### Triggers
- **Ingestion**: S3 events, API Gateway, Scheduled (daily)
- **Translation**: SQS queue, Step Functions
- **Check Professional**: API Gateway (sync)

## Error Handling & Retry Logic

### Retry Strategy
```python
@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=4, max=10)
)
def process_with_retry(data):
    try:
        return process_data(data)
    except TransientError:
        raise  # Will retry
    except PermanentError:
        log_error(data)
        return None  # Don't retry
```

### Dead Letter Queue
- Failed messages after retries go to DLQ
- Manual review process for DLQ items
- Alerting on DLQ depth

## Monitoring & Metrics

### CloudWatch Metrics
- Processing time per Lambda
- Success/failure rates
- Confidence score distribution
- Queue depths
- API response times

### Custom Metrics
```python
cloudwatch.put_metric_data(
    Namespace='Propelus/Taxonomy',
    MetricData=[
        {
            'MetricName': 'MappingConfidence',
            'Value': confidence_score,
            'Unit': 'Percent'
        }
    ]
)
```

### Alarms
- Lambda errors > 1% → Alert
- Processing time > 10s → Warning
- DLQ messages > 100 → Critical

## Testing Strategy

### Unit Tests
```python
def test_regex_rule():
    assert regex_rule("Advanced-Practice-Nurse", "Advanced Nurse")
    assert not regex_rule("Registered Nurse", "Advanced Nurse")
```

### Integration Tests
- Test full Bronze → Silver → Gold flow
- Validate rule priority system
- Check AI fallback behavior

### Load Tests
- 10,000 records in 5 minutes
- Concurrent API calls
- Large taxonomy hierarchies

## Deployment Pipeline

### CI/CD Flow
1. Code commit triggers build
2. Run unit tests
3. Deploy to dev environment
4. Run integration tests
5. Deploy to staging
6. Manual approval
7. Deploy to production

### Blue-Green Deployment
- Deploy new version to green environment
- Run smoke tests
- Switch traffic from blue to green
- Keep blue for rollback

## Performance Optimization

### Caching Strategy
- Cache taxonomy hierarchies (1 hour)
- Cache mapping rules (5 minutes)
- Cache AI embeddings (7 days)

### Batch Processing
```python
def process_batch(records):
    # Process in chunks of 100
    for chunk in chunks(records, 100):
        with ThreadPoolExecutor() as executor:
            results = executor.map(process_record, chunk)
    return results
```

### Connection Pooling
```python
# Reuse database connections
db_pool = create_connection_pool(
    min_size=5,
    max_size=20,
    timeout=30
)
```