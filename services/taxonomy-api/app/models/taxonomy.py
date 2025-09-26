"""
Database models for Bronze/Silver/Gold taxonomy architecture
"""
from datetime import datetime
from typing import Optional, List
from sqlalchemy import Column, Integer, String, DateTime, JSON, ForeignKey, Boolean, DECIMAL, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import JSONB, UUID
import uuid

Base = declarative_base()

# ============================================
# BRONZE LAYER MODELS
# ============================================

class BronzeTaxonomies(Base):
    __tablename__ = 'bronze_taxonomies'

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(Integer, nullable=False)
    row_json = Column(JSON, nullable=False)
    load_date = Column(DateTime, default=datetime.utcnow)
    type = Column(String(20), nullable=False)  # 'new' or 'updated'


class BronzeProfessions(Base):
    __tablename__ = 'bronze_professions'

    id = Column(Integer, primary_key=True, autoincrement=True)
    customer_id = Column(Integer, nullable=False)
    row_json = Column(JSON, nullable=False)
    load_date = Column(DateTime, default=datetime.utcnow)
    type = Column(String(20), nullable=False)  # 'new' or 'updated'


# ============================================
# SILVER LAYER - TAXONOMY MODELS
# ============================================

class SilverTaxonomies(Base):
    __tablename__ = 'silver_taxonomies'

    taxonomy_id = Column(Integer, primary_key=True)
    customer_id = Column(Integer)
    name = Column(String(255), nullable=False)
    type = Column(String(20), nullable=False)  # 'master' or 'customer'
    status = Column(String(20), default='active')
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    nodes = relationship("SilverTaxonomiesNodes", back_populates="taxonomy")


class SilverTaxonomiesNodesTypes(Base):
    __tablename__ = 'silver_taxonomies_nodes_types'

    node_type_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    status = Column(String(20), default='active')
    level = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    nodes = relationship("SilverTaxonomiesNodes", back_populates="node_type")


class SilverTaxonomiesNodes(Base):
    __tablename__ = 'silver_taxonomies_nodes'

    node_id = Column(Integer, primary_key=True)
    node_type_id = Column(Integer, ForeignKey('silver_taxonomies_nodes_types.node_type_id'))
    taxonomy_id = Column(Integer, ForeignKey('silver_taxonomies.taxonomy_id'))
    parent_node_id = Column(Integer, ForeignKey('silver_taxonomies_nodes.node_id'))
    value = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    taxonomy = relationship("SilverTaxonomies", back_populates="nodes")
    node_type = relationship("SilverTaxonomiesNodesTypes", back_populates="nodes")
    parent = relationship("SilverTaxonomiesNodes", remote_side=[node_id])
    children = relationship("SilverTaxonomiesNodes")
    attributes = relationship("SilverTaxonomiesNodesAttributes", back_populates="node")


class SilverTaxonomiesNodesAttributes(Base):
    __tablename__ = 'silver_taxonomies_nodes_attributes'

    attribute_id = Column(Integer, primary_key=True)
    node_id = Column(Integer, ForeignKey('silver_taxonomies_nodes.node_id'))
    name = Column(String(100), nullable=False)
    value = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    node = relationship("SilverTaxonomiesNodes", back_populates="attributes")


# ============================================
# SILVER LAYER - TAXONOMY MAPPING MODELS
# ============================================

class SilverMappingTaxonomiesRulesTypes(Base):
    __tablename__ = 'silver_mapping_taxonomies_rules_types'

    mapping_rule_type_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    command = Column(String(100), nullable=False)
    ai_mapping_flag = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    rules = relationship("SilverMappingTaxonomiesRules", back_populates="rule_type")


class SilverMappingTaxonomiesRules(Base):
    __tablename__ = 'silver_mapping_taxonomies_rules'

    mapping_rule_id = Column(Integer, primary_key=True)
    mapping_rule_type_id = Column(Integer, ForeignKey('silver_mapping_taxonomies_rules_types.mapping_rule_type_id'))
    name = Column(String(255), nullable=False)
    enabled = Column(Boolean, default=True)
    pattern = Column(Text)
    attributes = Column(JSONB)
    flags = Column(JSONB)
    action = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    rule_type = relationship("SilverMappingTaxonomiesRulesTypes", back_populates="rules")
    assignments = relationship("SilverMappingTaxonomiesRulesAssignment", back_populates="rule")


class SilverMappingTaxonomiesRulesAssignment(Base):
    __tablename__ = 'silver_mapping_taxonomies_rules_assignment'

    mapping_rule_assignment_id = Column(Integer, primary_key=True)
    mapping_rule_id = Column(Integer, ForeignKey('silver_mapping_taxonomies_rules.mapping_rule_id'))
    master_node_type_id = Column(Integer, ForeignKey('silver_taxonomies_nodes_types.node_type_id'))
    node_type_id = Column(Integer, ForeignKey('silver_taxonomies_nodes_types.node_type_id'))
    priority = Column(Integer, nullable=False)
    enabled = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    rule = relationship("SilverMappingTaxonomiesRules", back_populates="assignments")


class SilverMappingTaxonomies(Base):
    __tablename__ = 'silver_mapping_taxonomies'

    mapping_id = Column(Integer, primary_key=True)
    mapping_rule_id = Column(Integer, ForeignKey('silver_mapping_taxonomies_rules.mapping_rule_id'))
    master_node_id = Column(Integer, ForeignKey('silver_taxonomies_nodes.node_id'))
    node_id = Column(Integer, ForeignKey('silver_taxonomies_nodes.node_id'))
    confidence = Column(DECIMAL(5, 2))
    status = Column(String(20), default='active')
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    master_node = relationship("SilverTaxonomiesNodes", foreign_keys=[master_node_id])
    customer_node = relationship("SilverTaxonomiesNodes", foreign_keys=[node_id])


# ============================================
# SILVER LAYER - PROFESSION MODELS
# ============================================

class SilverProfessions(Base):
    __tablename__ = 'silver_professions'

    profession_id = Column(Integer, primary_key=True)
    customer_id = Column(Integer, nullable=False)
    name = Column(String(500), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    attributes = relationship("SilverProfessionsAttributes", back_populates="profession")


class SilverProfessionsAttributes(Base):
    __tablename__ = 'silver_professions_attributes'

    attribute_id = Column(Integer, primary_key=True)
    profession_id = Column(Integer, ForeignKey('silver_professions.profession_id'))
    name = Column(String(100), nullable=False)
    value = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    profession = relationship("SilverProfessions", back_populates="attributes")


# ============================================
# SILVER LAYER - PROFESSION MAPPING MODELS
# ============================================

class SilverMappingProfessionsRulesTypes(Base):
    __tablename__ = 'silver_mapping_professions_rules_types'

    mapping_rule_type_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    command = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    rules = relationship("SilverMappingProfessionsRules", back_populates="rule_type")


class SilverMappingProfessionsRules(Base):
    __tablename__ = 'silver_mapping_professions_rules'

    mapping_rule_id = Column(Integer, primary_key=True)
    mapping_rule_type_id = Column(Integer, ForeignKey('silver_mapping_professions_rules_types.mapping_rule_type_id'))
    name = Column(String(255), nullable=False)
    enabled = Column(Boolean, default=True)
    pattern = Column(Text)
    attributes = Column(JSONB)
    flags = Column(JSONB)
    action = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    rule_type = relationship("SilverMappingProfessionsRulesTypes", back_populates="rules")
    assignments = relationship("SilverMappingProfessionsRulesAssignment", back_populates="rule")


class SilverMappingProfessionsRulesAssignment(Base):
    __tablename__ = 'silver_mapping_professions_rules_assignment'

    mapping_rule_assignment_id = Column(Integer, primary_key=True)
    mapping_rule_id = Column(Integer, ForeignKey('silver_mapping_professions_rules.mapping_rule_id'))
    node_type_id = Column(Integer, ForeignKey('silver_taxonomies_nodes_types.node_type_id'))
    priority = Column(Integer, nullable=False)
    enabled = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    rule = relationship("SilverMappingProfessionsRules", back_populates="assignments")


class SilverMappingProfessions(Base):
    __tablename__ = 'silver_mapping_professions'

    mapping_id = Column(Integer, primary_key=True)
    mapping_rule_id = Column(Integer, ForeignKey('silver_mapping_professions_rules.mapping_rule_id'))
    node_id = Column(Integer, ForeignKey('silver_taxonomies_nodes.node_id'))
    profession_id = Column(Integer, ForeignKey('silver_professions.profession_id'))
    status = Column(String(20), default='active')
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    node = relationship("SilverTaxonomiesNodes")
    profession = relationship("SilverProfessions")


# ============================================
# AUDIT LOG MODEL
# ============================================

class SilverTaxonomiesLog(Base):
    __tablename__ = 'silver_taxonomies_log'

    id = Column(Integer, primary_key=True, autoincrement=True)
    taxonomy_id = Column(Integer, nullable=False)
    old_row = Column(JSONB)
    new_row = Column(JSONB)
    operation_type = Column(String(20), nullable=False)  # insert, update, delete
    operation_date = Column(DateTime, default=datetime.utcnow)
    user_name = Column(String(255))


# ============================================
# GOLD LAYER MODELS
# ============================================

class GoldTaxonomiesMapping(Base):
    __tablename__ = 'gold_taxonomies_mapping'

    mapping_id = Column(Integer, primary_key=True)
    master_node_id = Column(Integer, nullable=False)
    node_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class GoldMappingProfessions(Base):
    __tablename__ = 'gold_mapping_professions'

    mapping_id = Column(Integer, primary_key=True)
    node_id = Column(Integer, nullable=False)
    profession_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ============================================
# DATA SOURCE TRACKING (Migration 004)
# ============================================

class BronzeDataSources(Base):
    __tablename__ = 'bronze_data_sources'

    source_id = Column(Integer, primary_key=True)
    customer_id = Column(Integer, nullable=False)
    source_type = Column(String(50))  # 'api', 'file', 'manual', 'bucket'
    source_name = Column(String(255))
    source_url = Column(Text)
    request_id = Column(UUID(as_uuid=True), default=uuid.uuid4)
    session_id = Column(String(255))
    file_path = Column(Text)
    file_size_bytes = Column(Integer)
    record_count = Column(Integer)
    import_status = Column(String(50))  # 'pending', 'processing', 'completed', 'failed'
    error_message = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    processed_at = Column(DateTime)


class SilverAttributeTypes(Base):
    __tablename__ = 'silver_attribute_types'

    attribute_type_id = Column(Integer, primary_key=True)
    attribute_name = Column(String(100), nullable=False, unique=True)
    description = Column(Text)
    data_type = Column(String(50))  # 'string', 'number', 'boolean', 'date', 'array'
    is_required = Column(Boolean, default=False)
    applies_to = Column(String(50))  # 'node', 'profession', 'both'
    created_at = Column(DateTime, default=datetime.utcnow)


class ProcessingLog(Base):
    __tablename__ = 'processing_log'

    log_id = Column(Integer, primary_key=True)
    source_id = Column(Integer, ForeignKey('bronze_data_sources.source_id'))
    stage = Column(String(50))  # 'bronze_ingestion', 'silver_processing', etc.
    status = Column(String(50))  # 'started', 'completed', 'failed', 'skipped'
    records_processed = Column(Integer)
    records_failed = Column(Integer)
    processing_time_ms = Column(Integer)
    error_details = Column(JSONB)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    source = relationship("BronzeDataSources")


class MasterTaxonomyVersions(Base):
    __tablename__ = 'master_taxonomy_versions'

    version_id = Column(Integer, primary_key=True)
    version_number = Column(String(20), nullable=False, unique=True)
    description = Column(Text)
    total_nodes = Column(Integer)
    total_levels = Column(Integer)
    created_by = Column(String(255))
    created_at = Column(DateTime, default=datetime.utcnow)
    is_current = Column(Boolean, default=False)
    change_summary = Column(JSONB)


class APIContracts(Base):
    __tablename__ = 'api_contracts'

    contract_id = Column(Integer, primary_key=True)
    api_name = Column(String(100), nullable=False)
    version = Column(String(20), nullable=False)
    endpoint_path = Column(String(255))
    method = Column(String(10))  # 'GET', 'POST', 'PUT', 'DELETE', 'PATCH'
    request_schema = Column(JSONB)
    response_schema = Column(JSONB)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    deprecated_at = Column(DateTime)


class AuditLogEnhanced(Base):
    __tablename__ = 'audit_log_enhanced'

    log_id = Column(Integer, primary_key=True)
    table_name = Column(String(100), nullable=False)
    record_id = Column(Integer)
    operation = Column(String(20))  # 'insert', 'update', 'delete', 'merge'
    old_values = Column(JSONB)
    new_values = Column(JSONB)
    changed_fields = Column(JSONB)  # Array of field names
    user_id = Column(String(255))
    user_role = Column(String(100))
    source_system = Column(String(100))
    correlation_id = Column(UUID(as_uuid=True), default=uuid.uuid4)
    created_at = Column(DateTime, default=datetime.utcnow)


# ============================================
# CONTEXT AND TRANSLATION TABLES (Migration 003-004)
# ============================================

class SilverContextRules(Base):
    __tablename__ = 'silver_context_rules'

    rule_id = Column(Integer, primary_key=True)
    rule_name = Column(String(255), nullable=False)
    rule_type = Column(String(50))  # 'abbreviation', 'override', 'disambiguation', 'priority'
    pattern = Column(Text, nullable=False)
    context_key = Column(String(100))
    context_value = Column(Text)
    authority_id = Column(Integer, ForeignKey('silver_issuing_authorities.authority_id'))
    priority = Column(Integer, default=100)
    override_state = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    notes = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class SilverAttributeCombinations(Base):
    __tablename__ = 'silver_attribute_combinations'

    combination_id = Column(Integer, primary_key=True)
    customer_id = Column(Integer, nullable=False)
    state_code = Column(String(2))
    profession_code = Column(String(100))
    profession_description = Column(Text)
    issuing_authority = Column(String(255))
    additional_attributes = Column(JSONB)
    combination_hash = Column(String(64), unique=True)
    first_seen_date = Column(DateTime, default=datetime.utcnow)
    last_seen_date = Column(DateTime, default=datetime.utcnow)
    occurrence_count = Column(Integer, default=1)
    mapped_node_id = Column(Integer, ForeignKey('silver_taxonomies_nodes.node_id'))
    mapping_confidence = Column(DECIMAL(5, 2))
    mapping_status = Column(String(20))  # 'mapped', 'pending', 'failed', 'ambiguous'


class SilverTranslationPatterns(Base):
    __tablename__ = 'silver_translation_patterns'

    pattern_id = Column(Integer, primary_key=True)
    source_taxonomy_id = Column(Integer, ForeignKey('silver_taxonomies.taxonomy_id'))
    target_taxonomy_id = Column(Integer, ForeignKey('silver_taxonomies.taxonomy_id'))
    source_code = Column(String(100))
    source_attributes = Column(JSONB)
    result_count = Column(Integer)
    result_codes = Column(JSONB)  # Array of returned codes
    is_ambiguous = Column(Boolean, default=False)
    resolution_method = Column(String(50))
    first_requested = Column(DateTime, default=datetime.utcnow)
    last_requested = Column(DateTime, default=datetime.utcnow)
    request_count = Column(Integer, default=1)