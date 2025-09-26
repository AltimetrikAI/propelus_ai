"""
SQLAlchemy models for Profession Taxonomy
"""

from sqlalchemy import (
    Column, String, Integer, Boolean, ForeignKey, 
    DateTime, Text, Enum, DECIMAL, JSON, UniqueConstraint, Index
)
from sqlalchemy.dialects.postgresql import UUID, INET, JSONB
from sqlalchemy.orm import relationship, backref
from sqlalchemy.sql import func
import uuid
import enum

from app.core.database import Base

class ProfessionStatus(str, enum.Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    DEPRECATED = "deprecated"

class TranslationMethod(str, enum.Enum):
    AI = "ai"
    EXACT_MATCH = "exact_match"
    FUZZY_MATCH = "fuzzy_match"
    MANUAL = "manual"
    RULE_BASED = "rule_based"

class AuditAction(str, enum.Enum):
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
    APPROVE = "approve"
    REJECT = "reject"

class Profession(Base):
    __tablename__ = "professions"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    display_name = Column(String(255), nullable=False)
    parent_id = Column(UUID(as_uuid=True), ForeignKey("professions.id", ondelete="CASCADE"))
    level = Column(Integer, nullable=False, default=0)
    path = Column(Text)
    status = Column(Enum(ProfessionStatus), default=ProfessionStatus.ACTIVE, index=True)
    
    # Metadata
    description = Column(Text)
    regulatory_body = Column(String(255))
    license_required = Column(Boolean, default=False)
    specializations = Column(JSONB, default=list)
    related_codes = Column(JSONB, default=list)
    
    # Audit fields
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_by = Column(String(255))
    updated_by = Column(String(255))
    
    # Relationships
    parent = relationship("Profession", remote_side=[id], backref="children")
    aliases = relationship("ProfessionAlias", back_populates="profession", cascade="all, delete-orphan")
    translations = relationship("Translation", back_populates="profession")
    
    # Indexes
    __table_args__ = (
        Index("idx_professions_path", "path"),
        Index("idx_professions_path_gin", "path", postgresql_using="gin"),
    )
    
    def __repr__(self):
        return f"<Profession {self.code}: {self.name}>"
    
    @property
    def full_path(self):
        """Get the full hierarchical path as a list"""
        if not self.path:
            return []
        return self.path.strip("/").split("/")
    
    @property
    def ancestors(self):
        """Get all ancestor professions"""
        if not self.parent_id:
            return []
        ancestors = []
        current = self.parent
        while current:
            ancestors.append(current)
            current = current.parent
        return ancestors

class ProfessionAlias(Base):
    __tablename__ = "profession_aliases"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    profession_id = Column(UUID(as_uuid=True), ForeignKey("professions.id", ondelete="CASCADE"), nullable=False)
    alias = Column(String(255), nullable=False, index=True)
    alias_type = Column(String(50))
    source_system = Column(String(100))
    is_primary = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by = Column(String(255))
    
    # Relationships
    profession = relationship("Profession", back_populates="aliases")
    
    # Constraints
    __table_args__ = (
        UniqueConstraint("profession_id", "alias", name="unique_profession_alias"),
        Index("idx_aliases_alias_trgm", "alias", postgresql_using="gin"),
    )
    
    def __repr__(self):
        return f"<ProfessionAlias {self.alias} for {self.profession_id}>"

class Translation(Base):
    __tablename__ = "translations"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    
    # Input data
    input_text = Column(Text, nullable=False, index=True)
    input_context = Column(JSONB)
    source_system = Column(String(100))
    
    # Translation results
    matched_profession_id = Column(UUID(as_uuid=True), ForeignKey("professions.id"))
    confidence_score = Column(DECIMAL(5, 4))
    method = Column(Enum(TranslationMethod), nullable=False)
    alternative_matches = Column(JSONB, default=list)
    
    # Processing metadata
    processing_time_ms = Column(Integer)
    model_version = Column(String(50))
    model_response = Column(JSONB)
    
    # Review status
    reviewed = Column(Boolean, default=False, index=True)
    reviewed_by = Column(String(255))
    reviewed_at = Column(DateTime(timezone=True))
    review_notes = Column(Text)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    
    # Relationships
    profession = relationship("Profession", back_populates="translations")
    
    # Indexes
    __table_args__ = (
        Index("idx_translations_confidence", "confidence_score"),
    )
    
    def __repr__(self):
        return f"<Translation '{self.input_text[:50]}...' -> {self.matched_profession_id}>"

class AuditLog(Base):
    __tablename__ = "audit_logs"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entity_type = Column(String(50), nullable=False)
    entity_id = Column(UUID(as_uuid=True), nullable=False)
    action = Column(Enum(AuditAction), nullable=False, index=True)
    
    # Change tracking
    old_values = Column(JSONB)
    new_values = Column(JSONB)
    changes = Column(JSONB)
    
    # User tracking
    user_id = Column(String(255), nullable=False, index=True)
    user_email = Column(String(255))
    user_role = Column(String(50))
    ip_address = Column(INET)
    user_agent = Column(Text)
    
    # Additional context
    request_id = Column(UUID(as_uuid=True))
    session_id = Column(String(255))
    notes = Column(Text)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    
    # Indexes
    __table_args__ = (
        Index("idx_audit_entity", "entity_type", "entity_id"),
    )
    
    def __repr__(self):
        return f"<AuditLog {self.action} on {self.entity_type}:{self.entity_id}>"

class ProfessionHierarchy(Base):
    __tablename__ = "profession_hierarchy"
    
    ancestor_id = Column(UUID(as_uuid=True), ForeignKey("professions.id", ondelete="CASCADE"), primary_key=True)
    descendant_id = Column(UUID(as_uuid=True), ForeignKey("professions.id", ondelete="CASCADE"), primary_key=True)
    depth = Column(Integer, nullable=False)
    
    # Indexes
    __table_args__ = (
        Index("idx_hierarchy_ancestor", "ancestor_id"),
        Index("idx_hierarchy_descendant", "descendant_id"),
    )

class TranslationRule(Base):
    __tablename__ = "translation_rules"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pattern = Column(Text, nullable=False)
    profession_id = Column(UUID(as_uuid=True), ForeignKey("professions.id"), nullable=False)
    priority = Column(Integer, default=100)
    is_active = Column(Boolean, default=True, index=True)
    description = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    created_by = Column(String(255))
    
    # Indexes
    __table_args__ = (
        Index("idx_rules_priority", "priority"),
    )
    
    def __repr__(self):
        return f"<TranslationRule {self.pattern} -> {self.profession_id}>"