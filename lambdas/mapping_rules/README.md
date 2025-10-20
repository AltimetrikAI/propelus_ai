# Mapping Rules Lambda

## Overview

Multi-strategy taxonomy mapping Lambda that uses AI and deterministic matching to map customer profession codes to the master taxonomy.

## Matchers

### 1. Exact Matcher
- **Confidence**: 100%
- **Logic**: Case-insensitive exact string matching
- **Use Case**: Direct matches like "Nurse" → "Nurse"

### 2. NLP Qualifier Matcher
- **Confidence**: 90-95%
- **Logic**: Qualifier-aware pattern matching
- **Patterns**:
  - Strong occupation (multi-word detailed)
  - Qualified suffix (QUALIFIER + HEAD)
  - Qualified prefix (HEAD + QUALIFIER)
- **Use Case**: Context-dependent profession terms like "Clinical Nurse" vs "Nurse"
- **Example**: "Clinical Social Worker" → 95% confidence match

### 3. Fuzzy Matcher
- **Confidence**: 70-90%
- **Logic**: Levenshtein distance algorithm
- **Threshold**: 70% similarity required
- **Use Case**: Typos, variations ("Nurs" → "Nurse")

### 4. AI Semantic Matcher
- **Confidence**: Variable
- **Logic**: AWS Bedrock (Claude/Llama) with hierarchy context
- **Features**:
  - Full hierarchy path included in prompts
  - N/A nodes marked with [SKIP] for structural understanding
  - Semantic understanding of profession relationships
- **Use Case**: Complex semantic matching

## Matching Hierarchy

```
Customer Node
    ↓
1. Exact Matcher (100%)
    ↓ (if no match)
2. NLP Qualifier Matcher (90-95%)
    ↓ (if no match)
3. Fuzzy Matcher (70-90%)
    ↓ (if no match)
4. AI Semantic Matcher (variable)
    ↓ (if no match)
Low Confidence → Human Review Queue
```

## Architecture

```
src/
├── handler.ts                    # Main entry point
├── services/
│   ├── mapping-engine.ts         # Orchestrates matchers
│   └── vocabulary-extractor.ts   # Extracts vocabularies from taxonomy
├── matchers/
│   ├── exact-matcher.ts          # Exact string matching
│   ├── nlp-qualifier-matcher.ts  # NLP qualifier-aware matching
│   ├── fuzzy-matcher.ts          # Levenshtein distance matching
│   └── ai-semantic-matcher.ts    # AWS Bedrock semantic matching
└── utils/
    └── text-normalizer.ts        # Text preprocessing and tokenization
```

## Dependencies

```json
{
  "dependencies": {
    "@aws-sdk/client-bedrock-runtime": "^3.x",
    "string-similarity": "^4.0.4",
    "leven": "^3.1.0",
    "compromise": "^14.10.0",
    "pg": "^8.x"
  }
}
```

## Environment Variables

```bash
PGHOST=<aurora-endpoint>
PGPORT=5432
PGDATABASE=taxonomy
PGSCHEMA=taxonomy_schema
PGUSER=lambda_user
PGPASSWORD=<password>
PGSSLMODE=require
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
AWS_REGION=us-east-1
```

## Triggers

- EventBridge after Silver processing completes
- Direct invocation for testing

## Response

```json
{
  "node_id": 12345,
  "matched": true,
  "master_node_id": 67890,
  "confidence": 95,
  "method": "nlp_qualifier",
  "reasoning": "Strong occupation: Clinical Social Worker"
}
```

## Testing

```bash
npm test
```

## Build & Deploy

```bash
npm run build
npm run package
aws lambda update-function-code \
  --function-name propelus-mapping-rules \
  --zip-file fileb://function.zip
```

## See Also

- [Taxonomy Mapping Command Lambda](../taxonomy_mapping_command/) - Simple deterministic rules
- [Translation Lambda](../translation/) - Real-time translation
- [NLP Integration Docs](../../docs/nlp/)
