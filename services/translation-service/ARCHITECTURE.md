# GenAI Translation Service Architecture

## Overview
The Translation Service is an agentic AI system that maps non-standard healthcare profession text to the standardized taxonomy using AWS Bedrock and advanced NLP techniques.

## Architecture Design

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Translation Request                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Request Validator                         │
│              (Format, Length, Language Check)                │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                     Preprocessor Agent                       │
│         (Normalization, Tokenization, Cleaning)              │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
┌────────▼────────┐              ┌──────────▼──────────┐
│ Rule-Based      │              │ Semantic Search     │
│ Matcher         │              │ Agent               │
│ (Exact/Fuzzy)   │              │ (Vector Embeddings) │
└────────┬────────┘              └──────────┬──────────┘
         │                                   │
         └─────────────────┬─────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                      LLM Agent                              │
│            (AWS Bedrock - Claude 3 Sonnet)                  │
│         Context-aware profession matching                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Confidence Scorer                          │
│          (Multi-factor confidence calculation)               │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Result Validator                          │
│           (Hierarchy check, Business rules)                  │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                   Response Builder                           │
│         (Format response with alternatives)                  │
└─────────────────────────────────────────────────────────────┘
```

## Agent Framework Design

### 1. Preprocessor Agent
**Purpose**: Standardize and clean input text
**Components**:
- Text normalization (lowercase, remove special chars)
- Abbreviation expansion
- Spell correction
- Stop word removal
- Tokenization

### 2. Rule-Based Matcher Agent
**Purpose**: Fast, deterministic matching for known patterns
**Components**:
- Exact match lookup
- Fuzzy string matching (Levenshtein distance)
- Regex pattern matching
- Alias resolution

### 3. Semantic Search Agent
**Purpose**: Find similar professions using embeddings
**Components**:
- Text embedding generation (Bedrock Titan Embeddings)
- Vector similarity search (FAISS/Pinecone)
- Contextual relevance scoring
- Top-K candidate selection

### 4. LLM Translation Agent
**Purpose**: Intelligent matching using large language model
**Components**:
- Context building (candidate professions, descriptions)
- Prompt engineering with few-shot examples
- Chain-of-thought reasoning
- Structured output parsing

### 5. Confidence Scorer Agent
**Purpose**: Calculate match confidence
**Factors**:
- Method reliability weight
- Semantic similarity score
- String similarity score
- LLM confidence score
- Historical accuracy rate

### 6. Result Validator Agent
**Purpose**: Ensure results meet business rules
**Checks**:
- Valid taxonomy hierarchy
- Active profession status
- License requirements match
- Regulatory body alignment

## Implementation Stack

### Core Technologies
- **Framework**: LangChain/LangGraph for agent orchestration
- **LLM**: AWS Bedrock (Claude 3 Sonnet/Haiku)
- **Embeddings**: AWS Bedrock Titan Embeddings
- **Vector Store**: FAISS for local, Pinecone for production
- **Queue**: AWS SQS for async processing
- **Cache**: Redis for embedding cache

### Service Architecture
```python
# Agent Orchestration Flow
from langgraph.graph import Graph, END

workflow = Graph()

# Define nodes
workflow.add_node("preprocess", preprocess_agent)
workflow.add_node("rule_match", rule_matcher_agent)
workflow.add_node("semantic_search", semantic_search_agent)
workflow.add_node("llm_translate", llm_translation_agent)
workflow.add_node("score_confidence", confidence_scorer_agent)
workflow.add_node("validate", validator_agent)

# Define edges
workflow.add_edge("preprocess", "rule_match")
workflow.add_conditional_edges(
    "rule_match",
    should_continue_to_semantic,
    {
        "semantic": "semantic_search",
        "complete": "score_confidence"
    }
)
workflow.add_edge("semantic_search", "llm_translate")
workflow.add_edge("llm_translate", "score_confidence")
workflow.add_edge("score_confidence", "validate")
workflow.add_edge("validate", END)
```

## Confidence Scoring Algorithm

```python
def calculate_confidence(
    method: str,
    semantic_score: float,
    string_similarity: float,
    llm_confidence: float,
    historical_accuracy: float
) -> float:
    """
    Multi-factor confidence calculation
    """
    weights = {
        "exact_match": 1.0,
        "rule_based": 0.95,
        "fuzzy_match": 0.85,
        "semantic_search": 0.80,
        "llm_translation": 0.75
    }
    
    base_confidence = weights.get(method, 0.5)
    
    # Adjust based on similarity scores
    if semantic_score > 0:
        base_confidence *= (1 + semantic_score * 0.2)
    
    if string_similarity > 0:
        base_confidence *= (1 + string_similarity * 0.1)
    
    # Factor in LLM confidence
    if llm_confidence > 0:
        base_confidence = (base_confidence * 0.7) + (llm_confidence * 0.3)
    
    # Historical accuracy adjustment
    if historical_accuracy > 0:
        base_confidence = (base_confidence * 0.8) + (historical_accuracy * 0.2)
    
    return min(base_confidence, 1.0)
```

## Prompt Engineering

### Translation Prompt Template
```python
TRANSLATION_PROMPT = """
You are a healthcare profession taxonomy expert. Your task is to map the given profession text to the most appropriate standardized profession from our taxonomy.

Input Profession: {input_text}
Additional Context: {context}

Available Standard Professions:
{candidate_professions}

Instructions:
1. Analyze the input profession text carefully
2. Consider common variations, abbreviations, and related terms
3. Match to the most specific appropriate profession
4. If multiple matches are possible, rank them by relevance

Response Format:
{{
    "primary_match": {{
        "profession_id": "uuid",
        "profession_name": "name",
        "confidence": 0.00,
        "reasoning": "explanation"
    }},
    "alternative_matches": [
        {{
            "profession_id": "uuid",
            "profession_name": "name",
            "confidence": 0.00
        }}
    ]
}}

Examples:
Input: "RN" → Output: "Registered Nurse"
Input: "Physical Therapy Assistant" → Output: "Physical Therapist Assistant"
Input: "Dental Hygiene" → Output: "Dental Hygienist"

Now translate: {input_text}
"""
```

## Performance Optimization

### Caching Strategy
1. **Embedding Cache**: Store computed embeddings in Redis (TTL: 7 days)
2. **Translation Cache**: Cache successful translations (TTL: 24 hours)
3. **LLM Response Cache**: Cache for identical inputs (TTL: 1 hour)

### Batch Processing
- Queue translations for batch embedding generation
- Parallel processing for multiple translation requests
- Rate limiting to respect API quotas

### Monitoring Metrics
- Translation latency (p50, p95, p99)
- Cache hit ratio
- Confidence score distribution
- Method usage breakdown
- Error rates by component

## Error Handling

### Fallback Strategy
1. If LLM fails → Fall back to semantic search only
2. If embeddings fail → Fall back to rule-based matching
3. If all methods fail → Return top fuzzy matches with low confidence

### Retry Logic
```python
@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=2, max=10),
    retry=retry_if_exception_type(TransientError)
)
async def translate_with_retry(input_text: str) -> TranslationResult:
    return await translation_pipeline.run(input_text)
```

## Human-in-the-Loop Integration

### Review Triggers
- Confidence score < 0.7
- Multiple high-confidence alternatives
- New/unseen profession patterns
- Conflicting method results

### Feedback Loop
1. Collect human corrections
2. Store as training examples
3. Periodically retrain embeddings
4. Update translation rules
5. Adjust confidence weights

## API Endpoints

```yaml
POST /api/v1/translate
  Request:
    input_text: string
    context?: object
    options?:
      include_alternatives: boolean
      min_confidence: float
      methods: string[]
  
  Response:
    translation:
      profession_id: uuid
      profession_name: string
      profession_code: string
      confidence: float
      method: string
    alternatives: array
    metadata:
      processing_time_ms: int
      model_version: string

POST /api/v1/translate/batch
  Request:
    inputs: array<TranslationRequest>
    callback_url?: string
  
  Response:
    batch_id: uuid
    status: string
    estimated_completion: timestamp

GET /api/v1/translate/feedback/{translation_id}
POST /api/v1/translate/feedback/{translation_id}
```

## Deployment Considerations

### Container Configuration
```dockerfile
FROM python:3.11-slim

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Download models/embeddings
RUN python -m spacy download en_core_web_sm

# Copy application
COPY . /app
WORKDIR /app

# Run service
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

### Environment Variables
```bash
# AWS Configuration
AWS_REGION=us-east-1
BEDROCK_MODEL_ID=anthropic.claude-3-sonnet-20240229-v1:0
EMBEDDING_MODEL_ID=amazon.titan-embed-text-v1

# Service Configuration
CONFIDENCE_THRESHOLD=0.7
MAX_ALTERNATIVES=5
CACHE_TTL=3600

# Vector Store
VECTOR_STORE_TYPE=faiss
FAISS_INDEX_PATH=/data/faiss_index

# Performance
MAX_WORKERS=4
BATCH_SIZE=32
REQUEST_TIMEOUT=30
```