"""
API endpoints for admin operations and human review interface
"""
import json
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from pydantic import BaseModel, validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text, and_, or_, desc
from datetime import datetime, timedelta
import boto3
import os

from app.core.database import get_db

router = APIRouter()

# AWS clients
lambda_client = boto3.client('lambda')


# Request models
class CreateMasterNodeRequest(BaseModel):
    node_type_id: int
    parent_node_id: Optional[int] = None
    value: str
    attributes: Optional[Dict[str, Any]] = {}

    @validator('value')
    def validate_value(cls, v):
        if not v.strip():
            raise ValueError('Node value cannot be empty')
        return v.strip()


class UpdateMasterNodeRequest(BaseModel):
    value: Optional[str] = None
    parent_node_id: Optional[int] = None
    attributes: Optional[Dict[str, Any]] = None
    status: Optional[str] = None

    @validator('status')
    def validate_status(cls, v):
        if v and v not in ['active', 'inactive', 'deprecated']:
            raise ValueError('Status must be active, inactive, or deprecated')
        return v


class MasterTaxonomyVersionRequest(BaseModel):
    version_number: str
    description: str
    change_summary: Optional[Dict[str, Any]] = {}

    @validator('version_number')
    def validate_version(cls, v):
        if not v.strip():
            raise ValueError('Version number cannot be empty')
        return v.strip()


class DataLineageRequest(BaseModel):
    entity_type: str  # 'mapping', 'node', 'profession'
    entity_id: int
    include_related: bool = True


# Response models
class AdminStatsResponse(BaseModel):
    review_queue_size: int
    pending_mappings: int
    high_confidence_mappings: int
    failed_processing: int
    active_taxonomies: int
    total_nodes: int
    processing_rate_24h: int


class DataLineageResponse(BaseModel):
    entity_type: str
    entity_id: int
    lineage_path: List[Dict[str, Any]]
    related_entities: List[Dict[str, Any]]
    audit_trail: List[Dict[str, Any]]


@router.get("/admin/dashboard")
async def get_admin_dashboard(
    customer_id: Optional[int] = Query(None),
    db: AsyncSession = Depends(get_db)
):
    """
    Get admin dashboard statistics

    Provides overview of system health, processing status,
    and key metrics for administrative monitoring.
    """
    try:
        customer_filter = "AND st.customer_id = :customer_id" if customer_id else ""
        customer_params = {'customer_id': customer_id} if customer_id else {}

        # Review queue statistics
        review_stats_query = text(f"""
            SELECT
                COUNT(*) FILTER (WHERE sm.status = 'pending_review') as pending_review,
                COUNT(*) FILTER (WHERE sm.confidence >= 90) as high_confidence,
                COUNT(*) FILTER (WHERE sm.status = 'active') as active_mappings,
                COUNT(*) FILTER (WHERE sm.status = 'rejected') as rejected_mappings
            FROM silver_mapping_taxonomies sm
            JOIN silver_taxonomies_nodes sn ON sm.node_id = sn.node_id
            JOIN silver_taxonomies st ON sn.taxonomy_id = st.taxonomy_id
            WHERE 1=1 {customer_filter}
        """)

        review_result = await db.execute(review_stats_query, customer_params)
        review_stats = review_result.fetchone()

        # Processing statistics
        processing_stats_query = text("""
            SELECT
                COUNT(*) FILTER (WHERE import_status = 'processing') as processing,
                COUNT(*) FILTER (WHERE import_status = 'completed') as completed,
                COUNT(*) FILTER (WHERE import_status = 'failed') as failed,
                COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '24 hours') as processed_24h
            FROM bronze_data_sources
            WHERE (:customer_id IS NULL OR customer_id = :customer_id)
        """)

        processing_result = await db.execute(processing_stats_query, customer_params)
        processing_stats = processing_result.fetchone()

        # Taxonomy and node counts
        content_stats_query = text(f"""
            SELECT
                COUNT(DISTINCT st.taxonomy_id) as active_taxonomies,
                COUNT(sn.node_id) as total_nodes,
                COUNT(DISTINCT sn.node_type_id) as node_types
            FROM silver_taxonomies st
            LEFT JOIN silver_taxonomies_nodes sn ON st.taxonomy_id = sn.taxonomy_id
            WHERE st.status = 'active' {customer_filter}
        """)

        content_result = await db.execute(content_stats_query, customer_params)
        content_stats = content_result.fetchone()

        # Recent activity
        activity_query = text("""
            SELECT
                stage,
                status,
                COUNT(*) as count,
                MAX(created_at) as last_activity
            FROM processing_log
            WHERE created_at >= NOW() - INTERVAL '24 hours'
            GROUP BY stage, status
            ORDER BY last_activity DESC
            LIMIT 10
        """)

        activity_result = await db.execute(activity_query)
        recent_activity = activity_result.fetchall()

        return {
            'timestamp': datetime.utcnow().isoformat(),
            'customer_id': customer_id,
            'review_queue': {
                'pending_review': review_stats.pending_review or 0,
                'high_confidence': review_stats.high_confidence or 0,
                'active_mappings': review_stats.active_mappings or 0,
                'rejected_mappings': review_stats.rejected_mappings or 0
            },
            'processing': {
                'currently_processing': processing_stats.processing or 0,
                'completed': processing_stats.completed or 0,
                'failed': processing_stats.failed or 0,
                'processed_24h': processing_stats.processed_24h or 0
            },
            'content': {
                'active_taxonomies': content_stats.active_taxonomies or 0,
                'total_nodes': content_stats.total_nodes or 0,
                'node_types': content_stats.node_types or 0
            },
            'recent_activity': [
                {
                    'stage': activity.stage,
                    'status': activity.status,
                    'count': activity.count,
                    'last_activity': activity.last_activity.isoformat() if activity.last_activity else None
                }
                for activity in recent_activity
            ]
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving dashboard: {str(e)}")


@router.get("/admin/review-queue")
async def get_detailed_review_queue(
    customer_id: Optional[int] = Query(None),
    confidence_min: float = Query(0.0),
    confidence_max: float = Query(100.0),
    node_type: Optional[str] = Query(None),
    sort_by: str = Query('confidence_asc'),
    limit: int = Query(100, le=500),
    offset: int = Query(0),
    db: AsyncSession = Depends(get_db)
):
    """
    Get detailed review queue for human reviewers

    Returns mappings that need human review with full context,
    suggested alternatives, and historical information.
    """
    try:
        # Build conditions
        conditions = [
            "sm.status = 'pending_review'",
            "sm.confidence BETWEEN :confidence_min AND :confidence_max"
        ]
        params = {
            'confidence_min': confidence_min,
            'confidence_max': confidence_max,
            'limit': limit,
            'offset': offset
        }

        if customer_id:
            conditions.append("st.customer_id = :customer_id")
            params['customer_id'] = customer_id

        if node_type:
            conditions.append("snt.name = :node_type")
            params['node_type'] = node_type

        where_clause = "WHERE " + " AND ".join(conditions)

        # Determine sort order
        sort_options = {
            'confidence_asc': 'sm.confidence ASC',
            'confidence_desc': 'sm.confidence DESC',
            'created_asc': 'sm.created_at ASC',
            'created_desc': 'sm.created_at DESC',
            'customer': 'st.customer_id ASC, sm.confidence ASC'
        }
        order_clause = f"ORDER BY {sort_options.get(sort_by, 'sm.confidence ASC')}"

        # Main query for review items
        query = text(f"""
            SELECT
                sm.mapping_id,
                sm.confidence,
                sm.created_at,
                -- Source node information
                sn.node_id as source_node_id,
                sn.value as source_value,
                snt.name as source_node_type,
                snt.level as source_level,
                st.name as source_taxonomy,
                st.customer_id,
                -- Target node information
                tn.node_id as target_node_id,
                tn.value as target_value,
                tnt.name as target_node_type,
                tnt.level as target_level,
                tt.name as target_taxonomy,
                -- Rule information
                sr.name as rule_name,
                srt.name as rule_type,
                -- Get source node attributes
                (
                    SELECT json_agg(json_build_object('name', name, 'value', value))
                    FROM silver_taxonomies_nodes_attributes
                    WHERE node_id = sn.node_id
                ) as source_attributes,
                -- Get target node attributes
                (
                    SELECT json_agg(json_build_object('name', name, 'value', value))
                    FROM silver_taxonomies_nodes_attributes
                    WHERE node_id = tn.node_id
                ) as target_attributes
            FROM silver_mapping_taxonomies sm
            JOIN silver_taxonomies_nodes sn ON sm.node_id = sn.node_id
            JOIN silver_taxonomies st ON sn.taxonomy_id = st.taxonomy_id
            JOIN silver_taxonomies_nodes_types snt ON sn.node_type_id = snt.node_type_id
            JOIN silver_taxonomies_nodes tn ON sm.master_node_id = tn.node_id
            JOIN silver_taxonomies tt ON tn.taxonomy_id = tt.taxonomy_id
            JOIN silver_taxonomies_nodes_types tnt ON tn.node_type_id = tnt.node_type_id
            LEFT JOIN silver_mapping_taxonomies_rules sr ON sm.mapping_rule_id = sr.mapping_rule_id
            LEFT JOIN silver_mapping_taxonomies_rules_types srt ON sr.mapping_rule_type_id = srt.mapping_rule_type_id
            {where_clause}
            {order_clause}
            LIMIT :limit OFFSET :offset
        """)

        result = await db.execute(query, params)
        review_items = result.fetchall()

        # For each review item, get alternative suggestions
        detailed_items = []
        for item in review_items:
            # Get alternative mappings for the same source node
            alternatives_query = text("""
                SELECT
                    tn2.node_id,
                    tn2.value,
                    tnt2.name as node_type,
                    sm2.confidence,
                    sr2.name as rule_name
                FROM silver_mapping_taxonomies sm2
                JOIN silver_taxonomies_nodes tn2 ON sm2.master_node_id = tn2.node_id
                JOIN silver_taxonomies_nodes_types tnt2 ON tn2.node_type_id = tnt2.node_type_id
                LEFT JOIN silver_mapping_taxonomies_rules sr2 ON sm2.mapping_rule_id = sr2.mapping_rule_id
                WHERE sm2.node_id = :source_node_id
                AND sm2.mapping_id != :mapping_id
                AND sm2.status != 'rejected'
                ORDER BY sm2.confidence DESC
                LIMIT 5
            """)

            alternatives_result = await db.execute(alternatives_query, {
                'source_node_id': item.source_node_id,
                'mapping_id': item.mapping_id
            })
            alternatives = alternatives_result.fetchall()

            detailed_items.append({
                'mapping_id': item.mapping_id,
                'confidence': float(item.confidence) if item.confidence else 0.0,
                'created_at': item.created_at.isoformat() if item.created_at else None,
                'source_node': {
                    'node_id': item.source_node_id,
                    'value': item.source_value,
                    'type': item.source_node_type,
                    'level': item.source_level,
                    'taxonomy': item.source_taxonomy,
                    'customer_id': item.customer_id,
                    'attributes': item.source_attributes or []
                },
                'target_node': {
                    'node_id': item.target_node_id,
                    'value': item.target_value,
                    'type': item.target_node_type,
                    'level': item.target_level,
                    'taxonomy': item.target_taxonomy,
                    'attributes': item.target_attributes or []
                },
                'rule_info': {
                    'rule_name': item.rule_name,
                    'rule_type': item.rule_type
                },
                'alternatives': [
                    {
                        'node_id': alt.node_id,
                        'value': alt.value,
                        'type': alt.node_type,
                        'confidence': float(alt.confidence) if alt.confidence else 0.0,
                        'rule_name': alt.rule_name
                    }
                    for alt in alternatives
                ]
            })

        # Get total count for pagination
        count_query = text(f"""
            SELECT COUNT(*) as total
            FROM silver_mapping_taxonomies sm
            JOIN silver_taxonomies_nodes sn ON sm.node_id = sn.node_id
            JOIN silver_taxonomies st ON sn.taxonomy_id = st.taxonomy_id
            JOIN silver_taxonomies_nodes_types snt ON sn.node_type_id = snt.node_type_id
            {where_clause}
        """)

        count_result = await db.execute(count_query, {k: v for k, v in params.items()
                                                     if k not in ['limit', 'offset']})
        total_count = count_result.fetchone().total

        return {
            'review_items': detailed_items,
            'total': total_count,
            'limit': limit,
            'offset': offset,
            'filters': {
                'customer_id': customer_id,
                'confidence_range': [confidence_min, confidence_max],
                'node_type': node_type,
                'sort_by': sort_by
            }
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving review queue: {str(e)}")


@router.post("/admin/master-taxonomy/nodes")
async def create_master_node(
    request: CreateMasterNodeRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new node in the master taxonomy

    Allows administrators to manually add nodes to the master
    taxonomy for improved mapping coverage.
    """
    try:
        # Get master taxonomy ID
        master_taxonomy_query = text("""
            SELECT taxonomy_id FROM silver_taxonomies
            WHERE type = 'master'
            LIMIT 1
        """)

        result = await db.execute(master_taxonomy_query)
        master_taxonomy = result.fetchone()

        if not master_taxonomy:
            raise HTTPException(status_code=400, detail="Master taxonomy not found")

        # Validate node type exists
        node_type_query = text("""
            SELECT node_type_id, name, level FROM silver_taxonomies_nodes_types
            WHERE node_type_id = :node_type_id AND status = 'active'
        """)

        node_type_result = await db.execute(node_type_query, {'node_type_id': request.node_type_id})
        node_type = node_type_result.fetchone()

        if not node_type:
            raise HTTPException(status_code=400, detail="Invalid node type ID")

        # Validate parent node if specified
        if request.parent_node_id:
            parent_query = text("""
                SELECT node_id, node_type_id FROM silver_taxonomies_nodes
                WHERE node_id = :parent_node_id
                AND taxonomy_id = :taxonomy_id
            """)

            parent_result = await db.execute(parent_query, {
                'parent_node_id': request.parent_node_id,
                'taxonomy_id': master_taxonomy.taxonomy_id
            })

            parent_node = parent_result.fetchone()

            if not parent_node:
                raise HTTPException(status_code=400, detail="Invalid parent node ID")

            # Validate hierarchy (parent should be one level above)
            parent_type_query = text("""
                SELECT level FROM silver_taxonomies_nodes_types
                WHERE node_type_id = :node_type_id
            """)

            parent_type_result = await db.execute(parent_type_query, {'node_type_id': parent_node.node_type_id})
            parent_type = parent_type_result.fetchone()

            if parent_type and parent_type.level >= node_type.level:
                raise HTTPException(
                    status_code=400,
                    detail="Parent node must be at a higher level in the hierarchy"
                )

        # Create the new node
        create_node_query = text("""
            INSERT INTO silver_taxonomies_nodes
            (node_type_id, taxonomy_id, parent_node_id, value, created_at)
            VALUES (:node_type_id, :taxonomy_id, :parent_node_id, :value, NOW())
            RETURNING node_id
        """)

        create_result = await db.execute(create_node_query, {
            'node_type_id': request.node_type_id,
            'taxonomy_id': master_taxonomy.taxonomy_id,
            'parent_node_id': request.parent_node_id,
            'value': request.value
        })

        new_node_id = create_result.fetchone()[0]

        # Add attributes if provided
        if request.attributes:
            for attr_name, attr_value in request.attributes.items():
                attr_query = text("""
                    INSERT INTO silver_taxonomies_nodes_attributes
                    (node_id, name, value, created_at)
                    VALUES (:node_id, :name, :value, NOW())
                """)

                await db.execute(attr_query, {
                    'node_id': new_node_id,
                    'name': attr_name,
                    'value': str(attr_value)
                })

        await db.commit()

        return {
            'node_id': new_node_id,
            'node_type': node_type.name,
            'level': node_type.level,
            'value': request.value,
            'parent_node_id': request.parent_node_id,
            'attributes': request.attributes,
            'status': 'created',
            'message': 'Master taxonomy node created successfully'
        }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error creating node: {str(e)}")


@router.put("/admin/master-taxonomy/nodes/{node_id}")
async def update_master_node(
    node_id: int,
    request: UpdateMasterNodeRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Update a master taxonomy node

    Allows modification of master taxonomy nodes including
    value, parent relationships, and attributes.
    """
    try:
        # Verify node exists in master taxonomy
        node_query = text("""
            SELECT sn.node_id, sn.value, sn.node_type_id, sn.parent_node_id,
                   st.type as taxonomy_type
            FROM silver_taxonomies_nodes sn
            JOIN silver_taxonomies st ON sn.taxonomy_id = st.taxonomy_id
            WHERE sn.node_id = :node_id
        """)

        result = await db.execute(node_query, {'node_id': node_id})
        node = result.fetchone()

        if not node:
            raise HTTPException(status_code=404, detail="Node not found")

        if node.taxonomy_type != 'master':
            raise HTTPException(status_code=400, detail="Can only update master taxonomy nodes")

        # Build update query dynamically
        updates = []
        params = {'node_id': node_id}

        if request.value is not None:
            updates.append("value = :value")
            params['value'] = request.value

        if request.parent_node_id is not None:
            # Validate new parent if changing
            if request.parent_node_id != node.parent_node_id:
                # Validation logic similar to create_master_node
                pass
            updates.append("parent_node_id = :parent_node_id")
            params['parent_node_id'] = request.parent_node_id

        if updates:
            updates.append("last_updated_at = NOW()")
            update_query = text(f"""
                UPDATE silver_taxonomies_nodes
                SET {', '.join(updates)}
                WHERE node_id = :node_id
            """)

            await db.execute(update_query, params)

        # Update attributes if provided
        if request.attributes is not None:
            # Remove existing attributes
            delete_attrs_query = text("""
                DELETE FROM silver_taxonomies_nodes_attributes
                WHERE node_id = :node_id
            """)
            await db.execute(delete_attrs_query, {'node_id': node_id})

            # Add new attributes
            for attr_name, attr_value in request.attributes.items():
                attr_query = text("""
                    INSERT INTO silver_taxonomies_nodes_attributes
                    (node_id, name, value, created_at)
                    VALUES (:node_id, :name, :value, NOW())
                """)

                await db.execute(attr_query, {
                    'node_id': node_id,
                    'name': attr_name,
                    'value': str(attr_value)
                })

        await db.commit()

        return {
            'node_id': node_id,
            'status': 'updated',
            'message': 'Master taxonomy node updated successfully',
            'changes': {
                'value': request.value,
                'parent_node_id': request.parent_node_id,
                'attributes_updated': request.attributes is not None
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Error updating node: {str(e)}")


@router.get("/admin/data-lineage/{entity_type}/{entity_id}")
async def get_data_lineage(
    entity_type: str,
    entity_id: int,
    include_related: bool = Query(True),
    db: AsyncSession = Depends(get_db)
):
    """
    Get complete data lineage for an entity

    Traces the path of data from Bronze layer through Silver
    to Gold, showing all transformations and decisions.
    """
    try:
        if entity_type not in ['mapping', 'node', 'profession']:
            raise HTTPException(status_code=400, detail="Invalid entity type")

        lineage_path = []
        related_entities = []
        audit_trail = []

        if entity_type == 'mapping':
            # Get mapping lineage
            lineage_path, related_entities = await get_mapping_lineage(db, entity_id)

        elif entity_type == 'node':
            # Get node lineage
            lineage_path, related_entities = await get_node_lineage(db, entity_id)

        elif entity_type == 'profession':
            # Get profession lineage
            lineage_path, related_entities = await get_profession_lineage(db, entity_id)

        # Get audit trail
        audit_trail = await get_audit_trail(db, entity_type, entity_id)

        return DataLineageResponse(
            entity_type=entity_type,
            entity_id=entity_id,
            lineage_path=lineage_path,
            related_entities=related_entities if include_related else [],
            audit_trail=audit_trail
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving lineage: {str(e)}")


@router.post("/admin/system/reprocess")
async def trigger_system_reprocessing(
    processing_type: str = Query(..., regex="^(failed_only|all|mapping_rules)$"),
    customer_id: Optional[int] = Query(None),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    db: AsyncSession = Depends(get_db)
):
    """
    Trigger system-wide reprocessing

    Useful for applying updated rules, fixing failed processes,
    or refreshing the entire pipeline.
    """
    try:
        # Get sources to reprocess based on type
        if processing_type == 'failed_only':
            sources_query = text("""
                SELECT source_id FROM bronze_data_sources
                WHERE import_status = 'failed'
                AND (:customer_id IS NULL OR customer_id = :customer_id)
            """)
        elif processing_type == 'all':
            sources_query = text("""
                SELECT source_id FROM bronze_data_sources
                WHERE (:customer_id IS NULL OR customer_id = :customer_id)
                ORDER BY created_at DESC
                LIMIT 100  -- Limit to prevent overwhelming the system
            """)
        else:  # mapping_rules
            sources_query = text("""
                SELECT DISTINCT bds.source_id
                FROM bronze_data_sources bds
                JOIN processing_log pl ON bds.source_id = pl.source_id
                WHERE pl.stage = 'silver_processing'
                AND pl.status = 'completed'
                AND (:customer_id IS NULL OR bds.customer_id = :customer_id)
            """)

        result = await db.execute(sources_query, {'customer_id': customer_id})
        sources = result.fetchall()

        # Trigger reprocessing for each source
        reprocess_count = 0
        for source in sources:
            try:
                if processing_type == 'mapping_rules':
                    # Only reprocess mapping rules
                    lambda_client.invoke(
                        FunctionName='mapping-rules',
                        InvocationType='Event',
                        Payload=json.dumps({
                            'source_id': source.source_id,
                            'reprocess': True
                        })
                    )
                else:
                    # Full reprocessing from Bronze
                    lambda_client.invoke(
                        FunctionName='bronze-ingestion',
                        InvocationType='Event',
                        Payload=json.dumps({
                            'source_id': source.source_id,
                            'reprocess': True
                        })
                    )

                reprocess_count += 1

            except Exception as e:
                print(f"Failed to trigger reprocessing for source {source.source_id}: {e}")

        return {
            'status': 'triggered',
            'processing_type': processing_type,
            'customer_id': customer_id,
            'sources_queued': reprocess_count,
            'total_sources_found': len(sources),
            'estimated_completion_time': f'{reprocess_count * 2}-{reprocess_count * 5} minutes',
            'message': f'Reprocessing triggered for {reprocess_count} sources'
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error triggering reprocessing: {str(e)}")


# Helper functions for data lineage
async def get_mapping_lineage(db: AsyncSession, mapping_id: int) -> tuple[List[Dict], List[Dict]]:
    """Get lineage for a specific mapping"""
    # Implementation for mapping lineage
    return [], []


async def get_node_lineage(db: AsyncSession, node_id: int) -> tuple[List[Dict], List[Dict]]:
    """Get lineage for a specific node"""
    # Implementation for node lineage
    return [], []


async def get_profession_lineage(db: AsyncSession, profession_id: int) -> tuple[List[Dict], List[Dict]]:
    """Get lineage for a specific profession"""
    # Implementation for profession lineage
    return [], []


async def get_audit_trail(db: AsyncSession, entity_type: str, entity_id: int) -> List[Dict[str, Any]]:
    """Get audit trail for an entity"""
    query = text("""
        SELECT
            log_id,
            operation,
            old_values,
            new_values,
            changed_fields,
            user_id,
            source_system,
            created_at
        FROM audit_log_enhanced
        WHERE table_name LIKE :table_pattern
        AND record_id = :entity_id
        ORDER BY created_at DESC
        LIMIT 50
    """)

    table_pattern = f'%{entity_type}%'
    result = await db.execute(query, {
        'table_pattern': table_pattern,
        'entity_id': entity_id
    })

    audit_records = result.fetchall()

    return [
        {
            'log_id': record.log_id,
            'operation': record.operation,
            'old_values': record.old_values,
            'new_values': record.new_values,
            'changed_fields': record.changed_fields,
            'user_id': record.user_id,
            'source_system': record.source_system,
            'timestamp': record.created_at.isoformat() if record.created_at else None
        }
        for record in audit_records
    ]