"""
API endpoints for real-time taxonomy translation service
"""
import json
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel, validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
import boto3
import os
from datetime import datetime

from app.core.database import get_db

router = APIRouter()

# AWS clients
lambda_client = boto3.client('lambda')
TRANSLATION_LAMBDA = os.environ.get('TRANSLATION_LAMBDA', 'translation-service')


# Request models
class TranslationRequest(BaseModel):
    source_taxonomy: str
    target_taxonomy: str
    source_code: str
    attributes: Optional[Dict[str, Any]] = {}
    options: Optional[Dict[str, Any]] = {}

    @validator('source_taxonomy', 'target_taxonomy')
    def validate_taxonomies(cls, v):
        if not v.strip():
            raise ValueError('Taxonomy name cannot be empty')
        return v.strip()

    @validator('source_code')
    def validate_source_code(cls, v):
        if not v.strip():
            raise ValueError('Source code cannot be empty')
        return v.strip()


class BulkTranslationRequest(BaseModel):
    source_taxonomy: str
    target_taxonomy: str
    codes: List[Dict[str, Any]]  # [{"code": "RN", "attributes": {"state": "CA"}}]
    global_attributes: Optional[Dict[str, Any]] = {}
    options: Optional[Dict[str, Any]] = {}

    @validator('codes')
    def validate_codes(cls, v):
        if not v:
            raise ValueError('Codes list cannot be empty')

        for i, item in enumerate(v):
            if 'code' not in item:
                raise ValueError(f'Item {i} missing required "code" field')
            if not item['code'].strip():
                raise ValueError(f'Item {i} has empty code')

        return v


class TranslationFeedbackRequest(BaseModel):
    source_taxonomy: str
    target_taxonomy: str
    source_code: str
    attributes: Dict[str, Any]
    feedback_type: str  # 'correct', 'incorrect', 'missing'
    correct_target_code: Optional[str] = None
    comments: Optional[str] = None

    @validator('feedback_type')
    def validate_feedback_type(cls, v):
        if v not in ['correct', 'incorrect', 'missing']:
            raise ValueError('Feedback type must be correct, incorrect, or missing')
        return v


# Response models
class TranslationMatch(BaseModel):
    target_code: str
    target_node_id: int
    confidence: float
    layer: str  # 'gold' or 'silver'
    node_type: Optional[str]
    context_rule: Optional[str] = None
    authority_override: Optional[bool] = None
    via_master: Optional[bool] = None


class TranslationResponse(BaseModel):
    source_taxonomy: str
    target_taxonomy: str
    source_code: str
    source_match: Optional[Dict[str, Any]]
    matches: List[TranslationMatch]
    status: str
    total_matches: int
    timestamp: str
    processing_time_ms: Optional[int]


class BulkTranslationResponse(BaseModel):
    source_taxonomy: str
    target_taxonomy: str
    results: List[TranslationResponse]
    summary: Dict[str, int]
    total_processed: int
    processing_time_ms: int


@router.post("/translate", response_model=TranslationResponse)
async def translate_code(
    request: TranslationRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Translate a single code between taxonomies

    Performs real-time translation using Gold layer mappings with fallback
    to Silver layer for newer mappings. Applies context rules and issuing
    authority overrides for accurate results.

    Example:
    ```json
    {
        "source_taxonomy": "customer_123",
        "target_taxonomy": "master",
        "source_code": "ARNP",
        "attributes": {
            "state": "WA",
            "issuing_authority": "Washington State"
        },
        "options": {
            "include_alternatives": true,
            "min_confidence": 70.0
        }
    }
    ```
    """
    try:
        start_time = datetime.utcnow()

        # Validate taxonomies exist
        await validate_taxonomies(db, request.source_taxonomy, request.target_taxonomy)

        # Invoke translation Lambda
        payload = {
            'source_taxonomy': request.source_taxonomy,
            'target_taxonomy': request.target_taxonomy,
            'source_code': request.source_code,
            'attributes': request.attributes,
            'options': request.options
        }

        response = lambda_client.invoke(
            FunctionName=TRANSLATION_LAMBDA,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )

        # Parse Lambda response
        result_payload = json.loads(response['Payload'].read())

        if response['StatusCode'] != 200:
            raise HTTPException(
                status_code=result_payload.get('statusCode', 500),
                detail=result_payload.get('body', 'Translation failed')
            )

        translation_result = json.loads(result_payload['body'])

        # Calculate processing time
        end_time = datetime.utcnow()
        processing_time_ms = int((end_time - start_time).total_seconds() * 1000)

        # Format response
        matches = [
            TranslationMatch(**match) for match in translation_result.get('matches', [])
        ]

        response_obj = TranslationResponse(
            source_taxonomy=translation_result['source_taxonomy'],
            target_taxonomy=translation_result['target_taxonomy'],
            source_code=translation_result['source_code'],
            source_match=translation_result.get('source_match'),
            matches=matches,
            status=translation_result['status'],
            total_matches=translation_result['total_matches'],
            timestamp=translation_result['timestamp'],
            processing_time_ms=processing_time_ms
        )

        # Log translation for analytics (async)
        await log_translation_request(
            db,
            request,
            response_obj,
            processing_time_ms
        )

        return response_obj

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Translation error: {str(e)}")


@router.post("/translate/bulk", response_model=BulkTranslationResponse)
async def translate_bulk_codes(
    request: BulkTranslationRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Translate multiple codes in a single request

    Efficiently processes multiple codes with the same source and target
    taxonomies. Useful for batch processing and data migration.

    Example:
    ```json
    {
        "source_taxonomy": "customer_123",
        "target_taxonomy": "evercheck",
        "codes": [
            {"code": "RN", "attributes": {"state": "CA"}},
            {"code": "LPN", "attributes": {"state": "CA"}},
            {"code": "ARNP", "attributes": {"state": "WA"}}
        ],
        "global_attributes": {"license_type": "active"},
        "options": {"min_confidence": 80.0}
    }
    ```
    """
    try:
        start_time = datetime.utcnow()

        # Validate taxonomies exist
        await validate_taxonomies(db, request.source_taxonomy, request.target_taxonomy)

        results = []
        summary = {
            'successful': 0,
            'failed': 0,
            'no_matches': 0,
            'multiple_matches': 0,
            'high_confidence': 0
        }

        # Process each code
        for code_item in request.codes:
            try:
                # Merge global and item-specific attributes
                merged_attributes = {**request.global_attributes, **code_item.get('attributes', {})}

                # Create individual translation request
                individual_request = TranslationRequest(
                    source_taxonomy=request.source_taxonomy,
                    target_taxonomy=request.target_taxonomy,
                    source_code=code_item['code'],
                    attributes=merged_attributes,
                    options=request.options
                )

                # Translate individual code
                translation_result = await translate_code(individual_request, db)

                results.append(translation_result)

                # Update summary
                if translation_result.status == 'success':
                    summary['successful'] += 1
                    if translation_result.total_matches == 0:
                        summary['no_matches'] += 1
                    elif translation_result.total_matches > 1:
                        summary['multiple_matches'] += 1

                    if translation_result.matches and translation_result.matches[0].confidence >= 90:
                        summary['high_confidence'] += 1
                else:
                    summary['failed'] += 1

            except Exception as e:
                # Create error response for failed translation
                error_response = TranslationResponse(
                    source_taxonomy=request.source_taxonomy,
                    target_taxonomy=request.target_taxonomy,
                    source_code=code_item['code'],
                    source_match=None,
                    matches=[],
                    status='error',
                    total_matches=0,
                    timestamp=datetime.utcnow().isoformat(),
                    processing_time_ms=0
                )
                results.append(error_response)
                summary['failed'] += 1

        # Calculate total processing time
        end_time = datetime.utcnow()
        total_processing_time_ms = int((end_time - start_time).total_seconds() * 1000)

        # Log bulk translation (async)
        background_tasks.add_task(
            log_bulk_translation_request,
            db,
            request,
            results,
            total_processing_time_ms
        )

        return BulkTranslationResponse(
            source_taxonomy=request.source_taxonomy,
            target_taxonomy=request.target_taxonomy,
            results=results,
            summary=summary,
            total_processed=len(request.codes),
            processing_time_ms=total_processing_time_ms
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Bulk translation error: {str(e)}")


@router.get("/translate/patterns")
async def get_translation_patterns(
    source_taxonomy: Optional[str] = None,
    target_taxonomy: Optional[str] = None,
    is_ambiguous: Optional[bool] = None,
    min_requests: int = 2,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """
    Get translation patterns and analytics

    Returns frequently requested translations, ambiguous cases,
    and patterns that might need attention.
    """
    try:
        conditions = []
        params = {
            'min_requests': min_requests,
            'limit': limit
        }

        if source_taxonomy:
            # Get taxonomy ID
            source_id = await get_taxonomy_id_by_name(db, source_taxonomy)
            if source_id:
                conditions.append("source_taxonomy_id = :source_taxonomy_id")
                params['source_taxonomy_id'] = source_id

        if target_taxonomy:
            target_id = await get_taxonomy_id_by_name(db, target_taxonomy)
            if target_id:
                conditions.append("target_taxonomy_id = :target_taxonomy_id")
                params['target_taxonomy_id'] = target_id

        if is_ambiguous is not None:
            conditions.append("is_ambiguous = :is_ambiguous")
            params['is_ambiguous'] = is_ambiguous

        conditions.append("request_count >= :min_requests")

        where_clause = "WHERE " + " AND ".join(conditions)

        query = text(f"""
            SELECT
                stp.pattern_id,
                stp.source_code,
                stp.source_attributes,
                stp.result_count,
                stp.result_codes,
                stp.is_ambiguous,
                stp.resolution_method,
                stp.request_count,
                stp.first_requested,
                stp.last_requested,
                st.name as source_taxonomy_name,
                tt.name as target_taxonomy_name
            FROM silver_translation_patterns stp
            JOIN silver_taxonomies st ON stp.source_taxonomy_id = st.taxonomy_id
            JOIN silver_taxonomies tt ON stp.target_taxonomy_id = tt.taxonomy_id
            {where_clause}
            ORDER BY stp.request_count DESC, stp.last_requested DESC
            LIMIT :limit
        """)

        result = await db.execute(query, params)
        patterns = result.fetchall()

        formatted_patterns = []
        for pattern in patterns:
            formatted_patterns.append({
                'pattern_id': pattern.pattern_id,
                'source_taxonomy': pattern.source_taxonomy_name,
                'target_taxonomy': pattern.target_taxonomy_name,
                'source_code': pattern.source_code,
                'source_attributes': pattern.source_attributes,
                'result_count': pattern.result_count,
                'result_codes': pattern.result_codes,
                'is_ambiguous': pattern.is_ambiguous,
                'resolution_method': pattern.resolution_method,
                'request_count': pattern.request_count,
                'first_requested': pattern.first_requested.isoformat() if pattern.first_requested else None,
                'last_requested': pattern.last_requested.isoformat() if pattern.last_requested else None
            })

        return {
            'patterns': formatted_patterns,
            'total': len(formatted_patterns),
            'filters': {
                'source_taxonomy': source_taxonomy,
                'target_taxonomy': target_taxonomy,
                'is_ambiguous': is_ambiguous,
                'min_requests': min_requests
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving patterns: {str(e)}")


@router.post("/translate/feedback")
async def submit_translation_feedback(
    request: TranslationFeedbackRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Submit feedback on translation results

    Allows users to provide feedback on translation accuracy,
    which can be used to improve mapping rules and confidence scoring.
    """
    try:
        # Store feedback in database
        query = text("""
            INSERT INTO translation_feedback
            (source_taxonomy_name, target_taxonomy_name, source_code, attributes,
             feedback_type, correct_target_code, comments, created_at)
            VALUES (:source_taxonomy, :target_taxonomy, :source_code, :attributes,
                    :feedback_type, :correct_target_code, :comments, NOW())
            RETURNING feedback_id
        """)

        result = await db.execute(query, {
            'source_taxonomy': request.source_taxonomy,
            'target_taxonomy': request.target_taxonomy,
            'source_code': request.source_code,
            'attributes': json.dumps(request.attributes),
            'feedback_type': request.feedback_type,
            'correct_target_code': request.correct_target_code,
            'comments': request.comments
        })

        await db.commit()

        feedback_id = result.fetchone()[0]

        # If feedback indicates incorrect mapping, potentially trigger reprocessing
        if request.feedback_type == 'incorrect' and request.correct_target_code:
            # This could trigger a workflow to update mappings or create new rules
            pass

        return {
            'feedback_id': feedback_id,
            'status': 'received',
            'message': 'Thank you for your feedback',
            'feedback_type': request.feedback_type
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error submitting feedback: {str(e)}")


@router.get("/translate/health")
async def get_translation_health(db: AsyncSession = Depends(get_db)):
    """
    Get translation service health metrics

    Returns statistics about translation performance,
    cache hit rates, and system health.
    """
    try:
        # Get recent translation statistics
        stats_query = text("""
            SELECT
                COUNT(*) as total_requests,
                COUNT(*) FILTER (WHERE result_count > 0) as successful_translations,
                COUNT(*) FILTER (WHERE is_ambiguous = true) as ambiguous_cases,
                AVG(result_count) as avg_results_per_request,
                COUNT(DISTINCT source_taxonomy_id) as unique_source_taxonomies,
                COUNT(DISTINCT target_taxonomy_id) as unique_target_taxonomies
            FROM silver_translation_patterns
            WHERE last_requested >= NOW() - INTERVAL '24 hours'
        """)

        result = await db.execute(stats_query)
        stats = result.fetchone()

        # Get top translation pairs
        top_pairs_query = text("""
            SELECT
                st.name as source_taxonomy,
                tt.name as target_taxonomy,
                COUNT(*) as request_count,
                AVG(result_count) as avg_results
            FROM silver_translation_patterns stp
            JOIN silver_taxonomies st ON stp.source_taxonomy_id = st.taxonomy_id
            JOIN silver_taxonomies tt ON stp.target_taxonomy_id = tt.taxonomy_id
            WHERE stp.last_requested >= NOW() - INTERVAL '24 hours'
            GROUP BY st.name, tt.name
            ORDER BY request_count DESC
            LIMIT 10
        """)

        pairs_result = await db.execute(top_pairs_query)
        top_pairs = pairs_result.fetchall()

        return {
            'timestamp': datetime.utcnow().isoformat(),
            'statistics': {
                'total_requests_24h': stats.total_requests or 0,
                'successful_translations': stats.successful_translations or 0,
                'success_rate': (stats.successful_translations / stats.total_requests * 100) if stats.total_requests else 0,
                'ambiguous_cases': stats.ambiguous_cases or 0,
                'ambiguity_rate': (stats.ambiguous_cases / stats.total_requests * 100) if stats.total_requests else 0,
                'avg_results_per_request': float(stats.avg_results_per_request or 0),
                'unique_source_taxonomies': stats.unique_source_taxonomies or 0,
                'unique_target_taxonomies': stats.unique_target_taxonomies or 0
            },
            'top_translation_pairs': [
                {
                    'source_taxonomy': pair.source_taxonomy,
                    'target_taxonomy': pair.target_taxonomy,
                    'request_count': pair.request_count,
                    'avg_results': float(pair.avg_results)
                }
                for pair in top_pairs
            ],
            'status': 'healthy'
        }

    except Exception as e:
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'status': 'error',
            'error': str(e)
        }


# Helper functions
async def validate_taxonomies(db: AsyncSession, source_taxonomy: str, target_taxonomy: str):
    """Validate that taxonomies exist"""

    taxonomies_to_check = []

    # Handle special taxonomy names
    if source_taxonomy.lower() != 'master' and not source_taxonomy.startswith('customer_'):
        taxonomies_to_check.append(source_taxonomy)

    if target_taxonomy.lower() != 'master' and not target_taxonomy.startswith('customer_'):
        taxonomies_to_check.append(target_taxonomy)

    if taxonomies_to_check:
        query = text("""
            SELECT name FROM silver_taxonomies
            WHERE name = ANY(:taxonomy_names)
        """)

        result = await db.execute(query, {'taxonomy_names': taxonomies_to_check})
        found_taxonomies = {row.name for row in result.fetchall()}

        missing = set(taxonomies_to_check) - found_taxonomies
        if missing:
            raise HTTPException(
                status_code=400,
                detail=f"Taxonomies not found: {', '.join(missing)}"
            )


async def get_taxonomy_id_by_name(db: AsyncSession, taxonomy_name: str) -> Optional[int]:
    """Get taxonomy ID by name"""

    if taxonomy_name.lower() == 'master':
        query = text("""
            SELECT taxonomy_id FROM silver_taxonomies
            WHERE type = 'master'
            LIMIT 1
        """)
    elif taxonomy_name.startswith('customer_'):
        customer_id = int(taxonomy_name.split('_')[1])
        query = text("""
            SELECT taxonomy_id FROM silver_taxonomies
            WHERE customer_id = :customer_id AND type = 'customer'
            LIMIT 1
        """)
    else:
        query = text("""
            SELECT taxonomy_id FROM silver_taxonomies
            WHERE name = :taxonomy_name
            LIMIT 1
        """)

    params = {}
    if taxonomy_name.startswith('customer_'):
        params['customer_id'] = int(taxonomy_name.split('_')[1])
    elif taxonomy_name.lower() != 'master':
        params['taxonomy_name'] = taxonomy_name

    result = await db.execute(query, params)
    row = result.fetchone()

    return row.taxonomy_id if row else None


async def log_translation_request(
    db: AsyncSession,
    request: TranslationRequest,
    response: TranslationResponse,
    processing_time_ms: int
):
    """Log individual translation request for analytics"""

    try:
        query = text("""
            INSERT INTO api_request_log
            (endpoint, method, request_data, response_data, processing_time_ms,
             status_code, created_at)
            VALUES ('translate', 'POST', :request_data, :response_data, :processing_time_ms,
                    :status_code, NOW())
        """)

        await db.execute(query, {
            'request_data': json.dumps(request.dict()),
            'response_data': json.dumps(response.dict()),
            'processing_time_ms': processing_time_ms,
            'status_code': 200 if response.status == 'success' else 400
        })

        await db.commit()

    except Exception as e:
        # Don't fail translation due to logging errors
        print(f"Error logging translation request: {e}")


async def log_bulk_translation_request(
    db: AsyncSession,
    request: BulkTranslationRequest,
    results: List[TranslationResponse],
    processing_time_ms: int
):
    """Log bulk translation request for analytics"""

    try:
        query = text("""
            INSERT INTO api_request_log
            (endpoint, method, request_data, response_summary, processing_time_ms,
             status_code, created_at)
            VALUES ('translate/bulk', 'POST', :request_data, :response_summary,
                    :processing_time_ms, :status_code, NOW())
        """)

        # Create summary instead of full response to save space
        response_summary = {
            'total_processed': len(results),
            'successful': sum(1 for r in results if r.status == 'success'),
            'failed': sum(1 for r in results if r.status != 'success'),
            'total_matches': sum(r.total_matches for r in results)
        }

        await db.execute(query, {
            'request_data': json.dumps({
                'source_taxonomy': request.source_taxonomy,
                'target_taxonomy': request.target_taxonomy,
                'code_count': len(request.codes),
                'options': request.options
            }),
            'response_summary': json.dumps(response_summary),
            'processing_time_ms': processing_time_ms,
            'status_code': 200
        })

        await db.commit()

    except Exception as e:
        # Don't fail translation due to logging errors
        print(f"Error logging bulk translation request: {e}")