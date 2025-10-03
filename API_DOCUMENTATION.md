# Propelus AI Taxonomy Framework - API Documentation

## Overview

The Propelus Taxonomy API provides comprehensive endpoints for managing healthcare profession taxonomy mappings, translations, and administrative operations. **This API is designed for backend-to-backend communication** between internal Propelus services (EverCheck, DataSolutions, etc.) and is not intended for direct client access. The API follows REST principles and returns JSON responses.

**Last Updated**: September 29, 2025 - Post Architecture Simplification

## 🎯 Simplified Architecture (September 2025)

### Key Changes
The API has been updated to reflect the simplified architecture:

- **No customer taxonomies** - customers send profession lists only
- **Direct mapping** - professions map directly to master taxonomy
- **Request tracking** - all operations tracked with request_id
- **Async support** - webhook callbacks for long-running operations
- **Remapping** - version-based remapping when master taxonomy updates

### Two Primary Workflows

#### 1. Left-to-Right: Profession Mapping (Data Ingestion)
Customer sends profession lists → System maps to master taxonomy → Returns results
- Supports both sync and async processing
- Request ID for tracking
- Optional webhook callback

#### 2. Right-to-Left: Translation (Lookup Service)
Internal service queries profession code → System returns master taxonomy match
- Fully deterministic lookup
- Real-time responses
- No AI involved in translation

## Base URL

- **Development**: `http://localhost:8000/api/v1`
- **Staging**: `https://staging-api.propelus.ai/v1`
- **Production**: `https://api.propelus.ai/v1`

## Authentication

### API Key Authentication (Backend Services)
```bash
curl -H "X-API-Key: service-api-key" https://api.propelus.ai/v1/translate
```

### OAuth2 Client Credentials (Alternative)
```bash
# Get token
curl -X POST https://api.propelus.ai/oauth/token \
  -d "grant_type=client_credentials" \
  -d "client_id=your-client-id" \
  -d "client_secret=your-client-secret"

# Use token
curl -H "Authorization: Bearer <token>" https://api.propelus.ai/v1/translate
```

### Development (No Auth Required)
```bash
curl http://localhost:8000/api/v1/translate
```

## OpenAPI Documentation

Complete OpenAPI 3.0 specification is available:
- **Swagger UI**: `/docs`
- **OpenAPI Spec**: `/openapi.yaml`

## Common Response Format

### Success Response
```json
{
  "status": "success",
  "data": { ... },
  "timestamp": "2025-01-26T12:00:00Z"
}
```

### Error Response
```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input parameters",
    "details": { ... }
  },
  "timestamp": "2025-01-26T12:00:00Z"
}
```

## Endpoints

### 1. Taxonomy Management

#### List Taxonomies
```http
GET /taxonomies
```

**Parameters:**
- `type` (optional): Filter by type (`master` or `customer`)
- `status` (optional): Filter by status (`active` or `inactive`)
- `customer_id` (optional): Filter by customer ID

**Example:**
```bash
curl "http://localhost:8000/api/v1/taxonomies?type=customer&status=active"
```

**Response:**
```json
[
  {
    "taxonomy_id": 1,
    "customer_id": 123,
    "name": "Customer Healthcare Taxonomy",
    "type": "customer",
    "status": "active",
    "created_at": "2025-01-20T10:00:00Z"
  }
]
```

#### Get Taxonomy Details
```http
GET /taxonomies/{taxonomy_id}
```

**Example:**
```bash
curl http://localhost:8000/api/v1/taxonomies/1
```

#### Get Taxonomy Nodes
```http
GET /taxonomies/{taxonomy_id}/nodes
```

**Parameters:**
- `node_type_id` (optional): Filter by node type
- `parent_node_id` (optional): Filter by parent node

**Example:**
```bash
curl "http://localhost:8000/api/v1/taxonomies/1/nodes?node_type_id=3"
```

**Response:**
```json
[
  {
    "node_id": 101,
    "node_type": {
      "id": 3,
      "name": "Profession",
      "level": 6
    },
    "parent_node_id": 95,
    "value": "Registered Nurse",
    "created_at": "2025-01-20T10:00:00Z"
  }
]
```

### 2. Data Ingestion

#### Ingest Taxonomy Data
```http
POST /ingestion/bronze/taxonomies
```

**Request Body:**
```json
{
  "customer_id": 123,
  "data": [
    {
      "node_type": "profession",
      "value": "Registered Nurse",
      "parent_id": null,
      "attributes": {
        "state": "CA",
        "license_type": "RN"
      }
    }
  ],
  "source_name": "Customer Upload 2025-01",
  "overwrite": false
}
```

**Response:**
```json
{
  "source_id": 456,
  "status": "processing",
  "records_processed": 1,
  "message": "Taxonomy ingestion started for customer 123",
  "estimated_processing_time": "2-5 minutes"
}
```

#### Ingest Profession Data (Primary Workflow)
```http
POST /ingestion/bronze/professions
```

**Purpose**: Primary endpoint for customer data ingestion in the simplified model

**Request Body:**
```json
{
  "request_id": "req_abc123",
  "customer_id": 123,
  "data": [
    {
      "profession_code": "RN",
      "profession_name": "Registered Nurse",
      "state": "CA",
      "issuing_authority": "California Board of Nursing",
      "license_type": "active"
    },
    {
      "profession_code": "ARNP",
      "profession_name": "Advanced Registered Nurse Practitioner",
      "state": "WA"
    }
  ],
  "source_name": "Profession Import",
  "async": true,
  "callback_url": "https://customer-system.com/webhook/profession-mapping-complete"
}
```

**Response (Async):**
```json
{
  "request_id": "req_abc123",
  "load_id": 456,
  "status": "processing",
  "records_queued": 2,
  "message": "Profession mapping started for customer 123",
  "estimated_completion_time": "2-5 minutes",
  "callback_url": "https://customer-system.com/webhook/profession-mapping-complete"
}
```

**Response (Sync, for small batches):**
```json
{
  "request_id": "req_abc123",
  "load_id": 456,
  "status": "completed",
  "records_processed": 2,
  "mappings": [
    {
      "profession_code": "RN",
      "master_taxonomy_match": {
        "node_id": 1001,
        "value": "Registered Nurse",
        "confidence": 100.0,
        "status": "auto_approved"
      }
    },
    {
      "profession_code": "ARNP",
      "master_taxonomy_match": {
        "node_id": 1025,
        "value": "Advanced Practice Registered Nurse",
        "confidence": 85.0,
        "status": "pending_review"
      }
    }
  ]
}
```

#### Bulk Data Ingestion
```http
POST /ingestion/bronze/bulk
```

**Request Body:**
```json
{
  "customer_id": 123,
  "taxonomies": [ ... ],
  "professions": [ ... ],
  "source_name": "Complete Data Import"
}
```

#### Check Ingestion Status
```http
GET /ingestion/status/{source_id}
```

**Response:**
```json
{
  "source_id": 456,
  "status": "completed",
  "record_count": 150,
  "created_at": "2025-01-26T10:00:00Z",
  "processed_at": "2025-01-26T10:05:00Z",
  "error_message": null,
  "processing_stages": [
    {
      "stage": "bronze_ingestion",
      "status": "completed",
      "records_processed": 150,
      "records_failed": 0,
      "processing_time_ms": 2500,
      "timestamp": "2025-01-26T10:01:00Z"
    }
  ]
}
```

### 3. Translation Service (Backend-to-Backend)

#### Translate Profession Code
```http
POST /translate
```

**Purpose**: Translates profession codes between taxonomies for internal services (EverCheck, DataSolutions, etc.)

**Request Body:**
```json
{
  "source_taxonomy": "kaiser_permanente",
  "target_taxonomy": "evercheck_standard",
  "source_code": "RN",
  "attributes": [
    {
      "attribute_id": "state",
      "value": "CA"
    },
    {
      "attribute_id": "issuing_authority",
      "value": "California Board of Nursing"
    }
  ],
  "options": {
    "include_alternatives": true,
    "min_confidence": 70.0
  }
}
```

**Response:**
```json
{
  "request_id": "req_123456",
  "source_taxonomy": "kaiser_permanente",
  "target_taxonomy": "evercheck_standard",
  "source_code": "RN",
  "source_match": {
    "node_id": 101,
    "value": "RN",
    "taxonomy_id": 123,
    "customer_id": 1,
    "attributes": {
      "full_name": "Registered Nurse",
      "state": "CA"
    }
  },
  "master_taxonomy_match": {
    "node_id": 1000,
    "value": "Registered Nurse",
    "confidence": 95.0
  },
  "matches": [
    {
      "target_code": "RN-CA",
      "target_node_id": 2001,
      "confidence": 95.2,
      "layer": "gold",
      "node_type": "profession",
      "attributes": {
        "state": "CA",
        "license_type": "Active"
      },
      "taxonomy_name": "EverCheck Standard",
      "full_node_data": {
        "node_id": 2001,
        "value": "RN-CA",
        "type": "profession",
        "attributes": {
          "state": "CA",
          "license_type": "Active",
          "renewal_period": "2 years"
        }
      },
      "translation_path": {
        "source_to_master_confidence": 95.0,
        "master_to_target_confidence": 100.0
      }
    }
  ],
  "status": "success",
  "total_matches": 1,
  "timestamp": "2025-01-26T12:00:00Z"
}
```

#### Bulk Translation
```http
POST /translate/bulk
```

**Request Body:**
```json
{
  "source_taxonomy": "customer_123",
  "target_taxonomy": "evercheck",
  "codes": [
    {
      "code": "RN",
      "attributes": { "state": "CA" }
    },
    {
      "code": "LPN",
      "attributes": { "state": "CA" }
    }
  ],
  "global_attributes": {
    "license_type": "active"
  },
  "options": {
    "min_confidence": 80.0
  }
}
```

**Response:**
```json
{
  "source_taxonomy": "customer_123",
  "target_taxonomy": "evercheck",
  "results": [ ... ],
  "summary": {
    "successful": 2,
    "failed": 0,
    "no_matches": 0,
    "multiple_matches": 1,
    "high_confidence": 2
  },
  "total_processed": 2,
  "processing_time_ms": 450
}
```

#### Translation Patterns
```http
GET /translate/patterns
```

**Parameters:**
- `source_taxonomy` (optional): Filter by source taxonomy
- `target_taxonomy` (optional): Filter by target taxonomy
- `is_ambiguous` (optional): Filter ambiguous cases
- `min_requests` (optional): Minimum request count (default: 2)

**Response:**
```json
{
  "patterns": [
    {
      "pattern_id": 1,
      "source_taxonomy": "customer_123",
      "target_taxonomy": "master",
      "source_code": "RN",
      "source_attributes": {"state": "CA"},
      "result_count": 2,
      "result_codes": ["Registered Nurse - Acute Care", "Registered Nurse - General"],
      "is_ambiguous": true,
      "request_count": 25,
      "first_requested": "2025-01-20T10:00:00Z",
      "last_requested": "2025-01-26T11:30:00Z"
    }
  ],
  "total": 1
}
```

#### Submit Translation Feedback
```http
POST /translate/feedback
```

**Request Body:**
```json
{
  "source_taxonomy": "customer_123",
  "target_taxonomy": "master",
  "source_code": "RN",
  "attributes": {"state": "CA"},
  "feedback_type": "incorrect",
  "correct_target_code": "Registered Nurse - Critical Care",
  "comments": "The suggested mapping was too generic"
}
```

### 4. Mapping Management

#### Get Review Queue
```http
GET /mappings/review-queue
```

**Parameters:**
- `customer_id` (optional): Filter by customer
- `mapping_type` (optional): `taxonomy` or `profession`
- `min_confidence` (optional): Minimum confidence (0-100)
- `max_confidence` (optional): Maximum confidence (0-100)
- `limit` (optional): Number of results (default: 50)

**Response:**
```json
{
  "mappings": [
    {
      "mapping_id": 789,
      "mapping_type": "taxonomy",
      "source_node": {
        "node_id": 101,
        "value": "RN",
        "type": "profession",
        "taxonomy": "customer_123",
        "customer_id": 123
      },
      "target_node": {
        "node_id": 2001,
        "value": "Registered Nurse",
        "type": "profession",
        "taxonomy": "master"
      },
      "confidence": 82.5,
      "status": "pending_review",
      "created_at": "2025-01-26T10:00:00Z",
      "layer": "silver"
    }
  ],
  "total": 1,
  "pending_count": 15,
  "high_confidence_count": 8,
  "needs_review_count": 7
}
```

#### Approve Mapping
```http
POST /mappings/{mapping_id}/approve
```

**Query Parameters:**
- `mapping_type`: `taxonomy` or `profession`

**Request Body:**
```json
{
  "notes": "Approved after review",
  "confidence_override": 95.0
}
```

**Response:**
```json
{
  "mapping_id": 789,
  "status": "approved",
  "promoted_to_gold": true,
  "message": "Taxonomy mapping approved and promoted to Gold layer"
}
```

#### Reject Mapping
```http
POST /mappings/{mapping_id}/reject
```

**Request Body:**
```json
{
  "reason": "Incorrect mapping - too generic",
  "alternative_target_id": 2002,
  "notes": "Should map to specific specialty"
}
```

#### Create Manual Mapping
```http
POST /mappings/create
```

**Request Body:**
```json
{
  "source_node_id": 101,
  "target_node_id": 2001,
  "confidence": 100.0,
  "mapping_type": "taxonomy",
  "notes": "Manual mapping by domain expert"
}
```

#### Bulk Mapping Actions
```http
POST /mappings/bulk-action
```

**Query Parameters:**
- `mapping_type`: `taxonomy` or `profession`

**Request Body:**
```json
{
  "mapping_ids": [789, 790, 791],
  "action": "approve",
  "notes": "Bulk approval of high-confidence mappings"
}
```

### 5. Administrative Operations

#### Dashboard Statistics
```http
GET /admin/dashboard
```

**Parameters:**
- `customer_id` (optional): Filter by customer

**Response:**
```json
{
  "timestamp": "2025-01-26T12:00:00Z",
  "customer_id": null,
  "review_queue": {
    "pending_review": 15,
    "high_confidence": 8,
    "active_mappings": 1250,
    "rejected_mappings": 23
  },
  "processing": {
    "currently_processing": 2,
    "completed": 145,
    "failed": 3,
    "processed_24h": 12
  },
  "content": {
    "active_taxonomies": 5,
    "total_nodes": 12500,
    "node_types": 6
  }
}
```

#### Detailed Review Queue
```http
GET /admin/review-queue
```

**Parameters:**
- `customer_id` (optional)
- `confidence_min` (optional): 0-100
- `confidence_max` (optional): 0-100
- `node_type` (optional): Filter by node type name
- `sort_by` (optional): `confidence_asc`, `confidence_desc`, `created_desc`
- `limit` (optional): Max results
- `offset` (optional): Pagination offset

#### Create Master Taxonomy Node
```http
POST /admin/master-taxonomy/nodes
```

**Request Body:**
```json
{
  "node_type_id": 6,
  "parent_node_id": 2000,
  "value": "Certified Registered Nurse Anesthetist",
  "attributes": {
    "specialty": "anesthesia",
    "certification_required": true
  }
}
```

#### Update Master Taxonomy Node
```http
PUT /admin/master-taxonomy/nodes/{node_id}
```

**Request Body:**
```json
{
  "value": "Certified Registered Nurse Anesthetist (CRNA)",
  "attributes": {
    "specialty": "anesthesia",
    "certification_required": true,
    "advanced_practice": true
  }
}
```

#### Data Lineage
```http
GET /admin/data-lineage/{entity_type}/{entity_id}
```

**Parameters:**
- `entity_type`: `mapping`, `node`, or `profession`
- `entity_id`: ID of the entity
- `include_related` (optional): Include related entities (default: true)

**Response:**
```json
{
  "entity_type": "mapping",
  "entity_id": 789,
  "lineage_path": [
    {
      "stage": "bronze_ingestion",
      "timestamp": "2025-01-26T10:00:00Z",
      "source_id": 456,
      "data": { ... }
    },
    {
      "stage": "silver_processing",
      "timestamp": "2025-01-26T10:01:00Z",
      "transformations": [ ... ]
    }
  ],
  "related_entities": [ ... ],
  "audit_trail": [ ... ]
}
```

#### System Reprocessing
```http
POST /admin/system/reprocess
```

**Query Parameters:**
- `processing_type`: `failed_only`, `all`, or `mapping_rules`
- `customer_id` (optional): Filter by customer

**Response:**
```json
{
  "status": "triggered",
  "processing_type": "failed_only",
  "sources_queued": 5,
  "estimated_completion_time": "10-25 minutes"
}
```

### 6. Health and Monitoring

#### API Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-26T12:00:00Z",
  "version": "1.0.0",
  "environment": "production",
  "services": {
    "database": "healthy",
    "redis": "healthy",
    "external_apis": "healthy"
  }
}
```

#### Translation Service Health
```http
GET /translate/health
```

**Response:**
```json
{
  "timestamp": "2025-01-26T12:00:00Z",
  "statistics": {
    "total_requests_24h": 1250,
    "successful_translations": 1198,
    "success_rate": 95.84,
    "ambiguous_cases": 52,
    "ambiguity_rate": 4.16,
    "avg_results_per_request": 1.8,
    "unique_source_taxonomies": 5,
    "unique_target_taxonomies": 3
  },
  "status": "healthy"
}
```

## Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| VALIDATION_ERROR | 400 | Invalid request parameters |
| AUTHENTICATION_ERROR | 401 | Invalid API key or authentication |
| AUTHORIZATION_ERROR | 403 | Insufficient permissions |
| NOT_FOUND | 404 | Resource not found |
| CONFLICT | 409 | Resource already exists |
| RATE_LIMIT_EXCEEDED | 429 | Too many requests |
| INTERNAL_ERROR | 500 | Server error |
| SERVICE_UNAVAILABLE | 503 | Temporary service unavailability |

## Rate Limiting

- **Development**: No limits
- **Production**: 1000 requests/minute per API key
- **Burst**: Up to 2000 requests/minute for short periods

Rate limit headers:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 995
X-RateLimit-Reset: 1643211600
```

## SDK Examples

### TypeScript
```typescript
interface TranslationRequest {
  source_taxonomy: string;
  target_taxonomy: string;
  source_code: string;
  attributes?: Record<string, any>;
}

class PropellusTaxonomyClient {
  private baseUrl: string;
  private headers: Record<string, string>;

  constructor(baseUrl: string, apiKey?: string) {
    this.baseUrl = baseUrl;
    this.headers = { 'Content-Type': 'application/json' };
    if (apiKey) this.headers['X-API-Key'] = apiKey;
  }

  async translate(
    sourceTaxonomy: string,
    targetTaxonomy: string,
    sourceCode: string,
    attributes: Record<string, any> = {}
  ): Promise<any> {
    const response = await fetch(`${this.baseUrl}/translate`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({
        source_taxonomy: sourceTaxonomy,
        target_taxonomy: targetTaxonomy,
        source_code: sourceCode,
        attributes,
      }),
    });
    return response.json();
  }
}

// Usage
const client = new PropellusTaxonomyClient('https://api.propelus.ai/v1', 'your-api-key');
const result = await client.translate('customer_123', 'master', 'RN', { state: 'CA' });
```

---

*Last Updated: January 26, 2025*
*API Version: 1.0*