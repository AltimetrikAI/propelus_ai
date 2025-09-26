"""
API endpoints for profession management
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_

from app.core.database import get_db
from app.models.taxonomy import (
    SilverProfessions,
    SilverProfessionsAttributes,
    SilverMappingProfessions,
    GoldMappingProfessions
)

router = APIRouter()

@router.get("/professions")
async def list_professions(
    customer_id: Optional[int] = Query(None, description="Filter by customer ID"),
    name_contains: Optional[str] = Query(None, description="Filter by name substring"),
    limit: int = Query(100, le=1000),
    offset: int = Query(0),
    db: AsyncSession = Depends(get_db)
):
    """List professions with optional filters"""
    query = select(SilverProfessions)

    conditions = []
    if customer_id is not None:
        conditions.append(SilverProfessions.customer_id == customer_id)
    if name_contains:
        conditions.append(SilverProfessions.name.ilike(f"%{name_contains}%"))

    if conditions:
        query = query.where(and_(*conditions))

    query = query.offset(offset).limit(limit)

    result = await db.execute(query)
    professions = result.scalars().all()

    return [{
        "profession_id": p.profession_id,
        "customer_id": p.customer_id,
        "name": p.name,
        "created_at": p.created_at.isoformat() if p.created_at else None
    } for p in professions]


@router.get("/professions/{profession_id}")
async def get_profession(
    profession_id: int,
    include_attributes: bool = Query(True),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific profession by ID"""
    result = await db.execute(
        select(SilverProfessions).where(SilverProfessions.profession_id == profession_id)
    )
    profession = result.scalar_one_or_none()

    if not profession:
        raise HTTPException(status_code=404, detail="Profession not found")

    response = {
        "profession_id": profession.profession_id,
        "customer_id": profession.customer_id,
        "name": profession.name,
        "created_at": profession.created_at.isoformat() if profession.created_at else None,
        "last_updated_at": profession.last_updated_at.isoformat() if profession.last_updated_at else None
    }

    if include_attributes:
        attr_result = await db.execute(
            select(SilverProfessionsAttributes).where(
                SilverProfessionsAttributes.profession_id == profession_id
            )
        )
        attributes = attr_result.scalars().all()

        response["attributes"] = [{
            "name": attr.name,
            "value": attr.value
        } for attr in attributes]

    return response


@router.get("/professions/{profession_id}/attributes")
async def get_profession_attributes(
    profession_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get attributes for a specific profession"""
    result = await db.execute(
        select(SilverProfessionsAttributes).where(
            SilverProfessionsAttributes.profession_id == profession_id
        )
    )
    attributes = result.scalars().all()

    return [{
        "attribute_id": attr.attribute_id,
        "name": attr.name,
        "value": attr.value,
        "created_at": attr.created_at.isoformat() if attr.created_at else None
    } for attr in attributes]


@router.post("/professions/validate")
async def validate_profession(
    profession_name: str,
    customer_id: int,
    attributes: Optional[dict] = None,
    db: AsyncSession = Depends(get_db)
):
    """Validate if a profession exists in the system"""
    # Check for exact match
    result = await db.execute(
        select(SilverProfessions).where(
            and_(
                SilverProfessions.customer_id == customer_id,
                SilverProfessions.name == profession_name
            )
        )
    )
    profession = result.scalar_one_or_none()

    if profession:
        # Get mapping to taxonomy if exists
        mapping_result = await db.execute(
            select(SilverMappingProfessions).where(
                and_(
                    SilverMappingProfessions.profession_id == profession.profession_id,
                    SilverMappingProfessions.status == 'active'
                )
            )
        )
        mapping = mapping_result.scalar_one_or_none()

        return {
            "valid": True,
            "profession_id": profession.profession_id,
            "mapped_to_taxonomy": mapping is not None,
            "node_id": mapping.node_id if mapping else None
        }

    return {
        "valid": False,
        "profession_id": None,
        "mapped_to_taxonomy": False,
        "node_id": None,
        "message": "Profession not found in the system"
    }


@router.get("/mappings/professions")
async def get_profession_mappings(
    profession_id: Optional[int] = Query(None),
    node_id: Optional[int] = Query(None),
    customer_id: Optional[int] = Query(None),
    status: Optional[str] = Query(None),
    gold_only: bool = Query(False, description="Only show Gold layer approved mappings"),
    db: AsyncSession = Depends(get_db)
):
    """Get profession-to-taxonomy mappings"""
    if gold_only:
        query = select(GoldMappingProfessions)

        if node_id:
            query = query.where(GoldMappingProfessions.node_id == node_id)
        if profession_id:
            query = query.where(GoldMappingProfessions.profession_id == profession_id)

        result = await db.execute(query)
        mappings = result.scalars().all()

        return [{
            "mapping_id": m.mapping_id,
            "node_id": m.node_id,
            "profession_id": m.profession_id,
            "layer": "gold",
            "created_at": m.created_at.isoformat() if m.created_at else None
        } for m in mappings]
    else:
        query = select(
            SilverMappingProfessions,
            SilverProfessions
        ).join(
            SilverProfessions,
            SilverMappingProfessions.profession_id == SilverProfessions.profession_id
        )

        conditions = []
        if profession_id:
            conditions.append(SilverMappingProfessions.profession_id == profession_id)
        if node_id:
            conditions.append(SilverMappingProfessions.node_id == node_id)
        if customer_id is not None:
            conditions.append(SilverProfessions.customer_id == customer_id)
        if status:
            conditions.append(SilverMappingProfessions.status == status)

        if conditions:
            query = query.where(and_(*conditions))

        result = await db.execute(query)
        mappings = result.all()

        return [{
            "mapping_id": m.SilverMappingProfessions.mapping_id,
            "node_id": m.SilverMappingProfessions.node_id,
            "profession_id": m.SilverMappingProfessions.profession_id,
            "profession_name": m.SilverProfessions.name,
            "customer_id": m.SilverProfessions.customer_id,
            "status": m.SilverMappingProfessions.status,
            "layer": "silver",
            "created_at": m.SilverMappingProfessions.created_at.isoformat() if m.SilverMappingProfessions.created_at else None
        } for m in mappings]