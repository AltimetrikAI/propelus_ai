"""
API endpoints for taxonomy management
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.database import get_db
from app.models.taxonomy import (
    SilverTaxonomies,
    SilverTaxonomiesNodes,
    SilverTaxonomiesNodesTypes,
    SilverTaxonomiesNodesAttributes,
    SilverMappingTaxonomies,
    GoldTaxonomiesMapping
)

router = APIRouter()

@router.get("/taxonomies")
async def list_taxonomies(
    type: Optional[str] = Query(None, description="Filter by type: master or customer"),
    status: Optional[str] = Query(None, description="Filter by status: active or inactive"),
    customer_id: Optional[int] = Query(None, description="Filter by customer ID"),
    db: AsyncSession = Depends(get_db)
):
    """List all taxonomies with optional filters"""
    query = select(SilverTaxonomies)

    conditions = []
    if type:
        conditions.append(SilverTaxonomies.type == type)
    if status:
        conditions.append(SilverTaxonomies.status == status)
    if customer_id is not None:
        conditions.append(SilverTaxonomies.customer_id == customer_id)

    if conditions:
        query = query.where(and_(*conditions))

    result = await db.execute(query)
    taxonomies = result.scalars().all()

    return [{
        "taxonomy_id": t.taxonomy_id,
        "customer_id": t.customer_id,
        "name": t.name,
        "type": t.type,
        "status": t.status,
        "created_at": t.created_at.isoformat() if t.created_at else None
    } for t in taxonomies]


@router.get("/taxonomies/{taxonomy_id}")
async def get_taxonomy(
    taxonomy_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific taxonomy by ID"""
    result = await db.execute(
        select(SilverTaxonomies).where(SilverTaxonomies.taxonomy_id == taxonomy_id)
    )
    taxonomy = result.scalar_one_or_none()

    if not taxonomy:
        raise HTTPException(status_code=404, detail="Taxonomy not found")

    return {
        "taxonomy_id": taxonomy.taxonomy_id,
        "customer_id": taxonomy.customer_id,
        "name": taxonomy.name,
        "type": taxonomy.type,
        "status": taxonomy.status,
        "created_at": taxonomy.created_at.isoformat() if taxonomy.created_at else None,
        "last_updated_at": taxonomy.last_updated_at.isoformat() if taxonomy.last_updated_at else None
    }


@router.get("/taxonomies/{taxonomy_id}/nodes")
async def get_taxonomy_nodes(
    taxonomy_id: int,
    node_type_id: Optional[int] = Query(None, description="Filter by node type"),
    parent_node_id: Optional[int] = Query(None, description="Filter by parent node"),
    db: AsyncSession = Depends(get_db)
):
    """Get nodes for a specific taxonomy"""
    query = select(
        SilverTaxonomiesNodes,
        SilverTaxonomiesNodesTypes
    ).join(
        SilverTaxonomiesNodesTypes,
        SilverTaxonomiesNodes.node_type_id == SilverTaxonomiesNodesTypes.node_type_id
    ).where(
        SilverTaxonomiesNodes.taxonomy_id == taxonomy_id
    )

    if node_type_id is not None:
        query = query.where(SilverTaxonomiesNodes.node_type_id == node_type_id)

    if parent_node_id is not None:
        query = query.where(SilverTaxonomiesNodes.parent_node_id == parent_node_id)
    elif parent_node_id is None and node_type_id is None:
        # If no filters, return root nodes
        query = query.where(SilverTaxonomiesNodes.parent_node_id == None)

    result = await db.execute(query)
    nodes = result.all()

    return [{
        "node_id": node.SilverTaxonomiesNodes.node_id,
        "node_type": {
            "id": node.SilverTaxonomiesNodesTypes.node_type_id,
            "name": node.SilverTaxonomiesNodesTypes.name,
            "level": node.SilverTaxonomiesNodesTypes.level
        },
        "parent_node_id": node.SilverTaxonomiesNodes.parent_node_id,
        "value": node.SilverTaxonomiesNodes.value,
        "created_at": node.SilverTaxonomiesNodes.created_at.isoformat() if node.SilverTaxonomiesNodes.created_at else None
    } for node in nodes]


@router.get("/nodes/{node_id}/attributes")
async def get_node_attributes(
    node_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get attributes for a specific node"""
    result = await db.execute(
        select(SilverTaxonomiesNodesAttributes).where(
            SilverTaxonomiesNodesAttributes.node_id == node_id
        )
    )
    attributes = result.scalars().all()

    return [{
        "attribute_id": attr.attribute_id,
        "name": attr.name,
        "value": attr.value,
        "created_at": attr.created_at.isoformat() if attr.created_at else None
    } for attr in attributes]


@router.get("/node-types")
async def list_node_types(
    status: Optional[str] = Query(None, description="Filter by status"),
    db: AsyncSession = Depends(get_db)
):
    """List all node types"""
    query = select(SilverTaxonomiesNodesTypes).order_by(SilverTaxonomiesNodesTypes.level)

    if status:
        query = query.where(SilverTaxonomiesNodesTypes.status == status)

    result = await db.execute(query)
    node_types = result.scalars().all()

    return [{
        "node_type_id": nt.node_type_id,
        "name": nt.name,
        "level": nt.level,
        "status": nt.status
    } for nt in node_types]


@router.get("/mappings/taxonomies")
async def get_taxonomy_mappings(
    master_node_id: Optional[int] = Query(None),
    customer_node_id: Optional[int] = Query(None),
    min_confidence: Optional[float] = Query(None, ge=0, le=100),
    status: Optional[str] = Query(None),
    gold_only: bool = Query(False, description="Only show Gold layer approved mappings"),
    db: AsyncSession = Depends(get_db)
):
    """Get taxonomy-to-taxonomy mappings"""
    if gold_only:
        query = select(GoldTaxonomiesMapping)
        if master_node_id:
            query = query.where(GoldTaxonomiesMapping.master_node_id == master_node_id)
        if customer_node_id:
            query = query.where(GoldTaxonomiesMapping.node_id == customer_node_id)

        result = await db.execute(query)
        mappings = result.scalars().all()

        return [{
            "mapping_id": m.mapping_id,
            "master_node_id": m.master_node_id,
            "customer_node_id": m.node_id,
            "layer": "gold",
            "created_at": m.created_at.isoformat() if m.created_at else None
        } for m in mappings]
    else:
        query = select(SilverMappingTaxonomies)

        conditions = []
        if master_node_id:
            conditions.append(SilverMappingTaxonomies.master_node_id == master_node_id)
        if customer_node_id:
            conditions.append(SilverMappingTaxonomies.node_id == customer_node_id)
        if min_confidence is not None:
            conditions.append(SilverMappingTaxonomies.confidence >= min_confidence)
        if status:
            conditions.append(SilverMappingTaxonomies.status == status)

        if conditions:
            query = query.where(and_(*conditions))

        result = await db.execute(query)
        mappings = result.scalars().all()

        return [{
            "mapping_id": m.mapping_id,
            "master_node_id": m.master_node_id,
            "customer_node_id": m.node_id,
            "confidence": float(m.confidence) if m.confidence else None,
            "status": m.status,
            "layer": "silver",
            "created_at": m.created_at.isoformat() if m.created_at else None
        } for m in mappings]