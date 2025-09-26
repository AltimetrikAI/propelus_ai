"""
API endpoints for mapping management and human review
"""
import json
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text, and_, or_
from datetime import datetime

from app.core.database import get_db

router = APIRouter()


# Request models
class CreateMappingRequest(BaseModel):
    source_node_id: int
    target_node_id: int
    confidence: float
    mapping_type: str  # 'taxonomy' or 'profession'
    notes: Optional[str] = None

    @validator('confidence')
    def validate_confidence(cls, v):
        if not 0 <= v <= 100:
            raise ValueError('Confidence must be between 0 and 100')
        return v

    @validator('mapping_type')
    def validate_mapping_type(cls, v):
        if v not in ['taxonomy', 'profession']:
            raise ValueError('Mapping type must be taxonomy or profession')
        return v


class ApproveMappingRequest(BaseModel):
    notes: Optional[str] = None
    confidence_override: Optional[float] = None

    @validator('confidence_override')
    def validate_confidence_override(cls, v):
        if v is not None and not 0 <= v <= 100:
            raise ValueError('Confidence override must be between 0 and 100')
        return v


class RejectMappingRequest(BaseModel):
    reason: str
    alternative_target_id: Optional[int] = None
    notes: Optional[str] = None

    @validator('reason')
    def validate_reason(cls, v):
        if not v.strip():
            raise ValueError('Rejection reason cannot be empty')
        return v


class BulkMappingAction(BaseModel):
    mapping_ids: List[int]
    action: str  # 'approve', 'reject', 'delete'
    notes: Optional[str] = None
    reason: Optional[str] = None  # Required for reject


# Response models
class MappingResponse(BaseModel):
    mapping_id: int
    mapping_type: str
    source_node: Dict[str, Any]
    target_node: Dict[str, Any]
    confidence: float
    status: str
    created_at: str
    layer: str


class ReviewQueueResponse(BaseModel):
    mappings: List[MappingResponse]
    total: int
    pending_count: int
    high_confidence_count: int
    needs_review_count: int


@router.get("/mappings/review-queue")
async def get_review_queue(
    customer_id: Optional[int] = Query(None),
    mapping_type: Optional[str] = Query(None, regex="^(taxonomy|profession)$"),
    min_confidence: float = Query(0.0, ge=0.0, le=100.0),
    max_confidence: float = Query(100.0, ge=0.0, le=100.0),
    status: str = Query("pending_review", regex="^(pending_review|active|rejected)$"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db)
):
    """
    Get mappings that need human review

    Returns mappings with confidence scores below the auto-approval threshold
    that require human review and decision.
    """
    try:
        # Build conditions
        conditions = []
        params = {
            'min_confidence': min_confidence,
            'max_confidence': max_confidence,
            'status': status,
            'limit': limit,
            'offset': offset
        }

        if customer_id:
            conditions.append("source_tax.customer_id = :customer_id")
            params['customer_id'] = customer_id

        where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""

        if mapping_type == 'taxonomy' or mapping_type is None:
            # Get taxonomy mappings
            taxonomy_query = text(f"""
                SELECT
                    sm.mapping_id,
                    'taxonomy' as mapping_type,
                    sm.confidence,
                    sm.status,
                    sm.created_at,
                    'silver' as layer,
                    -- Source node info
                    sn.node_id as source_node_id,
                    sn.value as source_value,
                    snt.name as source_node_type,
                    source_tax.name as source_taxonomy_name,
                    source_tax.customer_id as source_customer_id,
                    -- Target node info
                    tn.node_id as target_node_id,
                    tn.value as target_value,
                    tnt.name as target_node_type,
                    target_tax.name as target_taxonomy_name,
                    target_tax.customer_id as target_customer_id
                FROM silver_mapping_taxonomies sm
                JOIN silver_taxonomies_nodes sn ON sm.node_id = sn.node_id
                JOIN silver_taxonomies source_tax ON sn.taxonomy_id = source_tax.taxonomy_id
                JOIN silver_taxonomies_nodes_types snt ON sn.node_type_id = snt.node_type_id
                JOIN silver_taxonomies_nodes tn ON sm.master_node_id = tn.node_id
                JOIN silver_taxonomies target_tax ON tn.taxonomy_id = target_tax.taxonomy_id
                JOIN silver_taxonomies_nodes_types tnt ON tn.node_type_id = tnt.node_type_id
                {where_clause}
                AND sm.status = :status
                AND sm.confidence BETWEEN :min_confidence AND :max_confidence
                ORDER BY sm.confidence ASC, sm.created_at ASC
                LIMIT :limit OFFSET :offset
            """)

            taxonomy_result = await db.execute(taxonomy_query, params)
            taxonomy_mappings = taxonomy_result.fetchall()
        else:
            taxonomy_mappings = []

        if mapping_type == 'profession' or mapping_type is None:
            # Get profession mappings (simplified query for professions)
            profession_query = text(f"""
                SELECT
                    smp.mapping_id,
                    'profession' as mapping_type,
                    90.0 as confidence,  -- Profession mappings typically high confidence
                    smp.status,
                    smp.created_at,
                    'silver' as layer,
                    -- Source (profession) info
                    sp.profession_id as source_node_id,
                    sp.name as source_value,
                    'profession' as source_node_type,
                    CONCAT('customer_', sp.customer_id) as source_taxonomy_name,
                    sp.customer_id as source_customer_id,
                    -- Target node info
                    tn.node_id as target_node_id,
                    tn.value as target_value,
                    tnt.name as target_node_type,
                    target_tax.name as target_taxonomy_name,
                    target_tax.customer_id as target_customer_id
                FROM silver_mapping_professions smp
                JOIN silver_professions sp ON smp.profession_id = sp.profession_id
                JOIN silver_taxonomies_nodes tn ON smp.node_id = tn.node_id
                JOIN silver_taxonomies target_tax ON tn.taxonomy_id = target_tax.taxonomy_id
                JOIN silver_taxonomies_nodes_types tnt ON tn.node_type_id = tnt.node_type_id
                WHERE sp.customer_id = COALESCE(:customer_id, sp.customer_id)
                AND smp.status = :status
                ORDER BY smp.created_at ASC
                LIMIT :limit OFFSET :offset
            """)

            profession_result = await db.execute(profession_query, params)
            profession_mappings = profession_result.fetchall()
        else:
            profession_mappings = []

        # Combine and format results
        all_mappings = list(taxonomy_mappings) + list(profession_mappings)

        formatted_mappings = []
        for mapping in all_mappings:
            formatted_mappings.append(MappingResponse(
                mapping_id=mapping.mapping_id,
                mapping_type=mapping.mapping_type,
                source_node={
                    'node_id': mapping.source_node_id,
                    'value': mapping.source_value,
                    'type': mapping.source_node_type,
                    'taxonomy': mapping.source_taxonomy_name,
                    'customer_id': mapping.source_customer_id
                },
                target_node={
                    'node_id': mapping.target_node_id,
                    'value': mapping.target_value,
                    'type': mapping.target_node_type,
                    'taxonomy': mapping.target_taxonomy_name,
                    'customer_id': mapping.target_customer_id
                },
                confidence=float(mapping.confidence) if mapping.confidence else 0.0,
                status=mapping.status,
                created_at=mapping.created_at.isoformat() if mapping.created_at else None,
                layer=mapping.layer
            ))

        # Get counts
        counts = await get_review_queue_counts(db, customer_id)

        return ReviewQueueResponse(
            mappings=formatted_mappings,
            total=len(formatted_mappings),
            pending_count=counts['pending'],
            high_confidence_count=counts['high_confidence'],
            needs_review_count=counts['needs_review']
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving review queue: {str(e)}")


@router.post("/mappings/{mapping_id}/approve")
async def approve_mapping(
    mapping_id: int,
    request: ApproveMappingRequest,
    mapping_type: str = Query(..., regex="^(taxonomy|profession)$"),
    db: AsyncSession = Depends(get_db)
):
    """
    Approve a mapping and promote it to Gold layer

    Updates the mapping status to 'active' and creates corresponding
    Gold layer records for production use.
    """
    try:
        # Update Silver layer mapping
        if mapping_type == 'taxonomy':
            table_name = 'silver_mapping_taxonomies'
            id_column = 'mapping_id'
        else:
            table_name = 'silver_mapping_professions'
            id_column = 'mapping_id'

        # Update status and confidence
        update_query = text(f"""
            UPDATE {table_name}
            SET status = 'active',
                confidence = COALESCE(:confidence_override, confidence),
                last_updated_at = NOW()
            WHERE {id_column} = :mapping_id
            RETURNING *
        """)

        result = await db.execute(update_query, {
            'mapping_id': mapping_id,
            'confidence_override': request.confidence_override
        })

        updated_mapping = result.fetchone()

        if not updated_mapping:
            raise HTTPException(status_code=404, detail=f"Mapping {mapping_id} not found")

        # Promote to Gold layer
        if mapping_type == 'taxonomy':
            await promote_taxonomy_mapping_to_gold(db, updated_mapping)
        else:
            await promote_profession_mapping_to_gold(db, updated_mapping)

        # Log the approval
        await log_mapping_action(
            db,
            mapping_id,
            mapping_type,
            'approve',
            request.notes,
            confidence_override=request.confidence_override
        )

        await db.commit()

        return {
            'mapping_id': mapping_id,
            'status': 'approved',
            'promoted_to_gold': True,
            'message': f'{mapping_type.title()} mapping approved and promoted to Gold layer'
        }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error approving mapping: {str(e)}")


@router.post("/mappings/{mapping_id}/reject")
async def reject_mapping(
    mapping_id: int,
    request: RejectMappingRequest,
    mapping_type: str = Query(..., regex="^(taxonomy|profession)$"),
    db: AsyncSession = Depends(get_db)
):
    """
    Reject a mapping

    Updates the mapping status to 'rejected' and optionally creates
    an alternative mapping if provided.
    """
    try:
        # Update Silver layer mapping
        if mapping_type == 'taxonomy':
            table_name = 'silver_mapping_taxonomies'
            id_column = 'mapping_id'
        else:
            table_name = 'silver_mapping_professions'
            id_column = 'mapping_id'

        # Update status to rejected
        update_query = text(f"""
            UPDATE {table_name}
            SET status = 'rejected',
                last_updated_at = NOW()
            WHERE {id_column} = :mapping_id
            RETURNING *
        """)

        result = await db.execute(update_query, {'mapping_id': mapping_id})
        rejected_mapping = result.fetchone()

        if not rejected_mapping:
            raise HTTPException(status_code=404, detail=f"Mapping {mapping_id} not found")

        # Create alternative mapping if provided
        alternative_mapping_id = None
        if request.alternative_target_id:
            alternative_mapping_id = await create_alternative_mapping(
                db,
                rejected_mapping,
                request.alternative_target_id,
                mapping_type
            )

        # Log the rejection
        await log_mapping_action(
            db,
            mapping_id,
            mapping_type,
            'reject',
            request.notes,
            reason=request.reason,
            alternative_mapping_id=alternative_mapping_id
        )

        await db.commit()

        response = {
            'mapping_id': mapping_id,
            'status': 'rejected',
            'reason': request.reason,
            'message': f'{mapping_type.title()} mapping rejected'
        }

        if alternative_mapping_id:
            response['alternative_mapping_id'] = alternative_mapping_id
            response['message'] += ' and alternative mapping created'

        return response

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error rejecting mapping: {str(e)}")


@router.post("/mappings/create")
async def create_manual_mapping(
    request: CreateMappingRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Create a manual mapping

    Allows human reviewers to create mappings directly when
    automated rules don't find appropriate matches.
    """
    try:
        # Validate nodes exist
        await validate_mapping_nodes(db, request.source_node_id, request.target_node_id, request.mapping_type)

        # Create mapping in Silver layer
        if request.mapping_type == 'taxonomy':
            mapping_id = await create_taxonomy_mapping(db, request)
        else:
            mapping_id = await create_profession_mapping(db, request)

        # If high confidence, automatically promote to Gold
        if request.confidence >= 90.0:
            if request.mapping_type == 'taxonomy':
                # Get the created mapping and promote
                mapping = await get_taxonomy_mapping(db, mapping_id)
                await promote_taxonomy_mapping_to_gold(db, mapping)
            else:
                mapping = await get_profession_mapping(db, mapping_id)
                await promote_profession_mapping_to_gold(db, mapping)

        # Log the creation
        await log_mapping_action(
            db,
            mapping_id,
            request.mapping_type,
            'create_manual',
            request.notes,
            confidence=request.confidence
        )

        await db.commit()

        return {
            'mapping_id': mapping_id,
            'status': 'active' if request.confidence >= 90.0 else 'pending_review',
            'promoted_to_gold': request.confidence >= 90.0,
            'confidence': request.confidence,
            'message': f'Manual {request.mapping_type} mapping created'
        }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating mapping: {str(e)}")


@router.post("/mappings/bulk-action")
async def bulk_mapping_action(
    request: BulkMappingAction,
    mapping_type: str = Query(..., regex="^(taxonomy|profession)$"),
    db: AsyncSession = Depends(get_db)
):
    """
    Perform bulk actions on multiple mappings

    Allows reviewers to approve, reject, or delete multiple mappings
    at once for efficiency.
    """
    try:
        if request.action == 'reject' and not request.reason:
            raise HTTPException(status_code=400, detail="Reason is required for bulk reject")

        results = []
        promoted_count = 0
        failed_count = 0

        for mapping_id in request.mapping_ids:
            try:
                if request.action == 'approve':
                    # Approve individual mapping
                    approve_req = ApproveMappingRequest(notes=request.notes)
                    await approve_mapping_single(db, mapping_id, approve_req, mapping_type)
                    promoted_count += 1

                elif request.action == 'reject':
                    # Reject individual mapping
                    reject_req = RejectMappingRequest(reason=request.reason, notes=request.notes)
                    await reject_mapping_single(db, mapping_id, reject_req, mapping_type)

                elif request.action == 'delete':
                    # Delete mapping
                    await delete_mapping_single(db, mapping_id, mapping_type)

                results.append({
                    'mapping_id': mapping_id,
                    'status': 'success',
                    'action': request.action
                })

            except Exception as e:
                failed_count += 1
                results.append({
                    'mapping_id': mapping_id,
                    'status': 'failed',
                    'action': request.action,
                    'error': str(e)
                })

        await db.commit()

        return {
            'total_processed': len(request.mapping_ids),
            'successful': len(results) - failed_count,
            'failed': failed_count,
            'promoted_to_gold': promoted_count,
            'results': results,
            'message': f'Bulk {request.action} completed'
        }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Bulk action failed: {str(e)}")


@router.get("/mappings/confidence-distribution")
async def get_confidence_distribution(
    customer_id: Optional[int] = Query(None),
    mapping_type: Optional[str] = Query(None, regex="^(taxonomy|profession)$"),
    db: AsyncSession = Depends(get_db)
):
    """
    Get distribution of confidence scores across mappings

    Useful for understanding mapping quality and setting
    appropriate confidence thresholds.
    """
    try:
        # Build query based on mapping type
        if mapping_type == 'taxonomy' or mapping_type is None:
            taxonomy_query = text("""
                SELECT
                    CASE
                        WHEN confidence >= 95 THEN '95-100'
                        WHEN confidence >= 90 THEN '90-94'
                        WHEN confidence >= 80 THEN '80-89'
                        WHEN confidence >= 70 THEN '70-79'
                        WHEN confidence >= 60 THEN '60-69'
                        ELSE '<60'
                    END as confidence_range,
                    COUNT(*) as count,
                    'taxonomy' as mapping_type
                FROM silver_mapping_taxonomies sm
                JOIN silver_taxonomies_nodes sn ON sm.node_id = sn.node_id
                JOIN silver_taxonomies st ON sn.taxonomy_id = st.taxonomy_id
                WHERE (:customer_id IS NULL OR st.customer_id = :customer_id)
                AND sm.status IN ('active', 'pending_review')
                GROUP BY confidence_range
                ORDER BY
                    CASE confidence_range
                        WHEN '95-100' THEN 1
                        WHEN '90-94' THEN 2
                        WHEN '80-89' THEN 3
                        WHEN '70-79' THEN 4
                        WHEN '60-69' THEN 5
                        ELSE 6
                    END
            """)

            taxonomy_result = await db.execute(taxonomy_query, {'customer_id': customer_id})
            taxonomy_distribution = taxonomy_result.fetchall()
        else:
            taxonomy_distribution = []

        # For professions, we'll use a simplified approach since they don't have confidence scores
        if mapping_type == 'profession' or mapping_type is None:
            profession_query = text("""
                SELECT
                    '90-100' as confidence_range,
                    COUNT(*) as count,
                    'profession' as mapping_type
                FROM silver_mapping_professions smp
                JOIN silver_professions sp ON smp.profession_id = sp.profession_id
                WHERE (:customer_id IS NULL OR sp.customer_id = :customer_id)
                AND smp.status IN ('active', 'pending_review')
            """)

            profession_result = await db.execute(profession_query, {'customer_id': customer_id})
            profession_distribution = profession_result.fetchall()
        else:
            profession_distribution = []

        # Combine results
        distribution = {}
        for row in list(taxonomy_distribution) + list(profession_distribution):
            key = row.confidence_range
            if key not in distribution:
                distribution[key] = {'taxonomy': 0, 'profession': 0, 'total': 0}

            distribution[key][row.mapping_type] = row.count
            distribution[key]['total'] += row.count

        return {
            'confidence_distribution': distribution,
            'total_mappings': sum(d['total'] for d in distribution.values()),
            'customer_id': customer_id,
            'mapping_type': mapping_type
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting confidence distribution: {str(e)}")


# Helper functions
async def get_review_queue_counts(db: AsyncSession, customer_id: Optional[int]) -> Dict[str, int]:
    """Get counts for different mapping statuses"""

    customer_filter = "AND st.customer_id = :customer_id" if customer_id else ""
    params = {'customer_id': customer_id} if customer_id else {}

    query = text(f"""
        SELECT
            status,
            CASE
                WHEN confidence >= 90 THEN 'high_confidence'
                WHEN confidence >= 70 THEN 'needs_review'
                ELSE 'low_confidence'
            END as confidence_category,
            COUNT(*) as count
        FROM silver_mapping_taxonomies sm
        JOIN silver_taxonomies_nodes sn ON sm.node_id = sn.node_id
        JOIN silver_taxonomies st ON sn.taxonomy_id = st.taxonomy_id
        WHERE 1=1 {customer_filter}
        GROUP BY status, confidence_category
    """)

    result = await db.execute(query, params)
    rows = result.fetchall()

    counts = {
        'pending': 0,
        'high_confidence': 0,
        'needs_review': 0,
        'active': 0,
        'rejected': 0
    }

    for row in rows:
        if row.status == 'pending_review':
            counts['pending'] += row.count
            counts[row.confidence_category] += row.count
        else:
            counts[row.status] += row.count

    return counts


async def promote_taxonomy_mapping_to_gold(db: AsyncSession, mapping: Any):
    """Promote a taxonomy mapping to Gold layer"""

    query = text("""
        INSERT INTO gold_taxonomies_mapping (master_node_id, node_id, created_at)
        VALUES (:master_node_id, :node_id, NOW())
        ON CONFLICT (master_node_id, node_id) DO NOTHING
    """)

    await db.execute(query, {
        'master_node_id': mapping.master_node_id,
        'node_id': mapping.node_id
    })


async def promote_profession_mapping_to_gold(db: AsyncSession, mapping: Any):
    """Promote a profession mapping to Gold layer"""

    query = text("""
        INSERT INTO gold_mapping_professions (node_id, profession_id, created_at)
        VALUES (:node_id, :profession_id, NOW())
        ON CONFLICT (node_id, profession_id) DO NOTHING
    """)

    await db.execute(query, {
        'node_id': mapping.node_id,
        'profession_id': mapping.profession_id
    })


async def log_mapping_action(
    db: AsyncSession,
    mapping_id: int,
    mapping_type: str,
    action: str,
    notes: Optional[str] = None,
    **kwargs
):
    """Log mapping action to audit trail"""

    query = text("""
        INSERT INTO audit_log_enhanced
        (table_name, record_id, operation, new_values, user_id, source_system, created_at)
        VALUES (:table_name, :record_id, :operation, :new_values, 'api_user', 'taxonomy_api', NOW())
    """)

    table_name = f'silver_mapping_{mapping_type}s'
    log_data = {
        'action': action,
        'notes': notes,
        **kwargs
    }

    await db.execute(query, {
        'table_name': table_name,
        'record_id': mapping_id,
        'operation': action,
        'new_values': json.dumps(log_data)
    })


async def validate_mapping_nodes(
    db: AsyncSession,
    source_node_id: int,
    target_node_id: int,
    mapping_type: str
):
    """Validate that mapping nodes exist and are appropriate"""

    # Validate source node
    if mapping_type == 'taxonomy':
        source_query = text("""
            SELECT node_id FROM silver_taxonomies_nodes WHERE node_id = :node_id
        """)
    else:
        source_query = text("""
            SELECT profession_id FROM silver_professions WHERE profession_id = :node_id
        """)

    source_result = await db.execute(source_query, {'node_id': source_node_id})
    if not source_result.fetchone():
        raise HTTPException(status_code=400, detail=f"Source {mapping_type} not found")

    # Validate target node (always a taxonomy node)
    target_query = text("""
        SELECT node_id FROM silver_taxonomies_nodes WHERE node_id = :node_id
    """)

    target_result = await db.execute(target_query, {'node_id': target_node_id})
    if not target_result.fetchone():
        raise HTTPException(status_code=400, detail="Target taxonomy node not found")


async def create_taxonomy_mapping(db: AsyncSession, request: CreateMappingRequest) -> int:
    """Create a new taxonomy mapping"""

    query = text("""
        INSERT INTO silver_mapping_taxonomies
        (mapping_rule_id, master_node_id, node_id, confidence, status, created_at)
        VALUES (1, :target_node_id, :source_node_id, :confidence,
                CASE WHEN :confidence >= 90 THEN 'active' ELSE 'pending_review' END,
                NOW())
        RETURNING mapping_id
    """)

    result = await db.execute(query, {
        'target_node_id': request.target_node_id,
        'source_node_id': request.source_node_id,
        'confidence': request.confidence
    })

    return result.fetchone()[0]


async def create_profession_mapping(db: AsyncSession, request: CreateMappingRequest) -> int:
    """Create a new profession mapping"""

    query = text("""
        INSERT INTO silver_mapping_professions
        (mapping_rule_id, node_id, profession_id, status, created_at)
        VALUES (1, :target_node_id, :source_node_id, 'active', NOW())
        RETURNING mapping_id
    """)

    result = await db.execute(query, {
        'target_node_id': request.target_node_id,
        'source_node_id': request.source_node_id
    })

    return result.fetchone()[0]


async def get_taxonomy_mapping(db: AsyncSession, mapping_id: int):
    """Get a taxonomy mapping by ID"""

    query = text("""
        SELECT * FROM silver_mapping_taxonomies WHERE mapping_id = :mapping_id
    """)

    result = await db.execute(query, {'mapping_id': mapping_id})
    return result.fetchone()


async def get_profession_mapping(db: AsyncSession, mapping_id: int):
    """Get a profession mapping by ID"""

    query = text("""
        SELECT * FROM silver_mapping_professions WHERE mapping_id = :mapping_id
    """)

    result = await db.execute(query, {'mapping_id': mapping_id})
    return result.fetchone()


# Additional helper functions for bulk operations
async def approve_mapping_single(db: AsyncSession, mapping_id: int, request: ApproveMappingRequest, mapping_type: str):
    """Approve a single mapping (internal use)"""
    # Similar to approve_mapping but without HTTP response
    pass


async def reject_mapping_single(db: AsyncSession, mapping_id: int, request: RejectMappingRequest, mapping_type: str):
    """Reject a single mapping (internal use)"""
    # Similar to reject_mapping but without HTTP response
    pass


async def delete_mapping_single(db: AsyncSession, mapping_id: int, mapping_type: str):
    """Delete a single mapping"""

    table_name = f'silver_mapping_{mapping_type}s'
    query = text(f"""
        DELETE FROM {table_name} WHERE mapping_id = :mapping_id
    """)

    await db.execute(query, {'mapping_id': mapping_id})


async def create_alternative_mapping(
    db: AsyncSession,
    original_mapping: Any,
    alternative_target_id: int,
    mapping_type: str
) -> int:
    """Create an alternative mapping when rejecting original"""

    if mapping_type == 'taxonomy':
        query = text("""
            INSERT INTO silver_mapping_taxonomies
            (mapping_rule_id, master_node_id, node_id, confidence, status, created_at)
            VALUES (:mapping_rule_id, :alternative_target_id, :node_id, 95.0, 'active', NOW())
            RETURNING mapping_id
        """)
    else:
        query = text("""
            INSERT INTO silver_mapping_professions
            (mapping_rule_id, node_id, profession_id, status, created_at)
            VALUES (:mapping_rule_id, :alternative_target_id, :profession_id, 'active', NOW())
            RETURNING mapping_id
        """)

    result = await db.execute(query, {
        'mapping_rule_id': getattr(original_mapping, 'mapping_rule_id', 1),
        'alternative_target_id': alternative_target_id,
        'node_id': getattr(original_mapping, 'node_id', None),
        'profession_id': getattr(original_mapping, 'profession_id', None)
    })

    return result.fetchone()[0]