"""
Test Fixtures and Sample Data for Propelus AI Taxonomy Framework
Provides reusable test data for unit and integration tests
"""

from datetime import datetime, timedelta
import json
from typing import List, Dict, Any


class SampleTaxonomyData:
    """Sample taxonomy data for testing"""

    @staticmethod
    def get_master_taxonomy() -> Dict[str, Any]:
        """Get sample master taxonomy structure"""
        return {
            "taxonomy_id": 1,
            "name": "Master Healthcare Taxonomy",
            "type": "master",
            "nodes": [
                {
                    "node_id": 1,
                    "value": "Healthcare Services",
                    "level": 1,
                    "children": [
                        {
                            "node_id": 10,
                            "value": "Clinical Services",
                            "level": 2,
                            "children": [
                                {
                                    "node_id": 100,
                                    "value": "Nursing",
                                    "level": 3,
                                    "children": [
                                        {"node_id": 1000, "value": "Registered Nurse", "level": 4},
                                        {"node_id": 1001, "value": "Licensed Practical Nurse", "level": 4},
                                        {"node_id": 1002, "value": "Nurse Practitioner", "level": 4}
                                    ]
                                },
                                {
                                    "node_id": 101,
                                    "value": "Medical",
                                    "level": 3,
                                    "children": [
                                        {"node_id": 1010, "value": "Physician", "level": 4},
                                        {"node_id": 1011, "value": "Surgeon", "level": 4},
                                        {"node_id": 1012, "value": "Anesthesiologist", "level": 4}
                                    ]
                                }
                            ]
                        },
                        {
                            "node_id": 11,
                            "value": "Allied Health",
                            "level": 2,
                            "children": [
                                {
                                    "node_id": 110,
                                    "value": "Therapy Services",
                                    "level": 3,
                                    "children": [
                                        {"node_id": 1100, "value": "Physical Therapist", "level": 4},
                                        {"node_id": 1101, "value": "Occupational Therapist", "level": 4},
                                        {"node_id": 1102, "value": "Speech Therapist", "level": 4}
                                    ]
                                }
                            ]
                        }
                    ]
                }
            ]
        }

    @staticmethod
    def get_customer_taxonomy(customer_id: int) -> Dict[str, Any]:
        """Get sample customer taxonomy"""
        return {
            "taxonomy_id": 100 + customer_id,
            "name": f"Customer {customer_id} Taxonomy",
            "type": "customer",
            "customer_id": customer_id,
            "nodes": [
                {
                    "node_id": 2000 + customer_id,
                    "value": "RN",
                    "attributes": {"full_name": "Registered Nurse", "state": "CA"}
                },
                {
                    "node_id": 2001 + customer_id,
                    "value": "MD",
                    "attributes": {"full_name": "Medical Doctor", "state": "NY"}
                },
                {
                    "node_id": 2002 + customer_id,
                    "value": "PT",
                    "attributes": {"full_name": "Physical Therapist", "state": "TX"}
                }
            ]
        }


class SampleProfessionData:
    """Sample profession data for testing"""

    @staticmethod
    def get_professions_csv() -> str:
        """Get sample CSV data for professions"""
        return """profession_code,profession_name,state,license_type,issuing_authority,status
RN,Registered Nurse,CA,Active,California Board of Registered Nursing,Active
LPN,Licensed Practical Nurse,CA,Active,California Board of Vocational Nursing,Active
MD,Medical Doctor,NY,Active,New York State Board of Medicine,Active
DO,Doctor of Osteopathy,NY,Active,New York State Board of Medicine,Active
PT,Physical Therapist,TX,Active,Texas Board of Physical Therapy Examiners,Active
OT,Occupational Therapist,TX,Inactive,Texas Board of Occupational Therapy Examiners,Inactive
ACLS,Advanced Cardiac Life Support,,Active,American Heart Association,Active
BLS,Basic Life Support,,Active,American Heart Association,Active
ARRT,Radiologic Technologist,,Active,American Registry of Radiologic Technologists,Active"""

    @staticmethod
    def get_professions_json() -> List[Dict[str, Any]]:
        """Get sample JSON data for professions"""
        return [
            {
                "profession_code": "RN",
                "profession_name": "Registered Nurse",
                "profession_description": "Provides patient care and health education",
                "state": "CA",
                "license_type": "Active",
                "issuing_authority": "California Board of Registered Nursing",
                "renewal_period_months": 24,
                "ce_requirements": 30
            },
            {
                "profession_code": "NP",
                "profession_name": "Nurse Practitioner",
                "profession_description": "Advanced practice registered nurse",
                "state": "CA",
                "license_type": "Active",
                "issuing_authority": "California Board of Registered Nursing",
                "renewal_period_months": 24,
                "ce_requirements": 50
            },
            {
                "profession_code": "MD",
                "profession_name": "Physician",
                "profession_description": "Medical doctor providing diagnosis and treatment",
                "state": "NY",
                "license_type": "Active",
                "issuing_authority": "New York State Board of Medicine",
                "renewal_period_months": 36,
                "ce_requirements": 100
            }
        ]

    @staticmethod
    def get_national_certifications() -> List[Dict[str, Any]]:
        """Get sample national certification data"""
        return [
            {
                "code": "ACLS",
                "name": "Advanced Cardiac Life Support",
                "issuing_authority": "American Heart Association",
                "is_national": True,
                "renewal_period_months": 24
            },
            {
                "code": "BLS",
                "name": "Basic Life Support",
                "issuing_authority": "American Heart Association",
                "is_national": True,
                "renewal_period_months": 24
            },
            {
                "code": "PALS",
                "name": "Pediatric Advanced Life Support",
                "issuing_authority": "American Heart Association",
                "is_national": True,
                "renewal_period_months": 24
            },
            {
                "code": "ARRT",
                "name": "Registered Radiologic Technologist",
                "issuing_authority": "American Registry of Radiologic Technologists",
                "is_national": True,
                "renewal_period_months": 12
            }
        ]


class SampleMappingData:
    """Sample mapping data for testing"""

    @staticmethod
    def get_mapping_rules() -> List[Dict[str, Any]]:
        """Get sample mapping rules"""
        return [
            {
                "rule_id": 1,
                "name": "Exact Match RN",
                "rule_type": "exact_match",
                "pattern": "RN|Registered Nurse",
                "target": "Registered Nurse",
                "confidence": 100,
                "priority": 1
            },
            {
                "rule_id": 2,
                "name": "Fuzzy Match Nurse",
                "rule_type": "fuzzy_match",
                "pattern": ".*[Nn]urse.*",
                "confidence": 85,
                "priority": 2
            },
            {
                "rule_id": 3,
                "name": "Context ACLS",
                "rule_type": "context",
                "pattern": "ACLS",
                "context_key": "issuing_authority",
                "context_value": "American Heart Association",
                "confidence": 100,
                "priority": 1
            }
        ]

    @staticmethod
    def get_sample_mappings() -> List[Dict[str, Any]]:
        """Get sample taxonomy mappings"""
        return [
            {
                "mapping_id": 1,
                "source_node_id": 2000,  # Customer RN
                "target_node_id": 1000,  # Master Registered Nurse
                "confidence": 95.0,
                "status": "active",
                "rule_id": 1
            },
            {
                "mapping_id": 2,
                "source_node_id": 2001,  # Customer MD
                "target_node_id": 1010,  # Master Physician
                "confidence": 92.0,
                "status": "active",
                "rule_id": 2
            },
            {
                "mapping_id": 3,
                "source_node_id": 2002,  # Customer PT
                "target_node_id": 1100,  # Master Physical Therapist
                "confidence": 88.0,
                "status": "pending_review",
                "rule_id": 2
            }
        ]


class SampleTranslationData:
    """Sample translation request/response data"""

    @staticmethod
    def get_translation_request() -> Dict[str, Any]:
        """Get sample translation request"""
        return {
            "source_taxonomy": "customer_1",
            "target_taxonomy": "master",
            "source_code": "RN",
            "attributes": {
                "state": "CA",
                "license_type": "Active"
            },
            "options": {
                "include_alternatives": True,
                "min_confidence": 80.0
            }
        }

    @staticmethod
    def get_translation_response() -> Dict[str, Any]:
        """Get expected translation response"""
        return {
            "source_taxonomy": "customer_1",
            "target_taxonomy": "master",
            "source_code": "RN",
            "source_match": {
                "node_id": 2000,
                "value": "RN",
                "taxonomy_id": 101,
                "customer_id": 1
            },
            "matches": [
                {
                    "target_code": "Registered Nurse",
                    "target_node_id": 1000,
                    "confidence": 95.0,
                    "layer": "gold",
                    "node_type": "profession"
                }
            ],
            "status": "success",
            "processing_time_ms": 45
        }


class SampleProcessingData:
    """Sample data for processing pipeline tests"""

    @staticmethod
    def get_bronze_data() -> Dict[str, Any]:
        """Get sample bronze layer data"""
        return {
            "source_id": 123,
            "customer_id": 1,
            "source_type": "csv",
            "source_name": "customer_upload_20240926.csv",
            "records": [
                {"row_number": 1, "row_json": {"code": "RN", "name": "Registered Nurse"}},
                {"row_number": 2, "row_json": {"code": "MD", "name": "Medical Doctor"}},
                {"row_number": 3, "row_json": {"code": "PT", "name": "Physical Therapist"}}
            ],
            "created_at": datetime.now().isoformat()
        }

    @staticmethod
    def get_silver_data() -> Dict[str, Any]:
        """Get sample silver layer data"""
        return {
            "taxonomy_id": 101,
            "customer_id": 1,
            "nodes": [
                {
                    "node_id": 2000,
                    "value": "RN",
                    "node_type_id": 1,
                    "attributes": [
                        {"name": "full_name", "value": "Registered Nurse"},
                        {"name": "state", "value": "CA"}
                    ]
                }
            ],
            "professions": [
                {
                    "profession_id": 3000,
                    "name": "Registered Nurse",
                    "customer_id": 1,
                    "attributes": [
                        {"name": "license_type", "value": "Active"},
                        {"name": "state", "value": "CA"}
                    ]
                }
            ]
        }

    @staticmethod
    def get_processing_log() -> List[Dict[str, Any]]:
        """Get sample processing log entries"""
        return [
            {
                "log_id": 1,
                "source_id": 123,
                "stage": "bronze_ingestion",
                "status": "completed",
                "records_processed": 100,
                "created_at": datetime.now().isoformat()
            },
            {
                "log_id": 2,
                "source_id": 123,
                "stage": "silver_processing",
                "status": "completed",
                "records_processed": 98,
                "created_at": (datetime.now() + timedelta(minutes=5)).isoformat()
            },
            {
                "log_id": 3,
                "source_id": 123,
                "stage": "mapping_rules",
                "status": "in_progress",
                "records_processed": 45,
                "created_at": (datetime.now() + timedelta(minutes=10)).isoformat()
            }
        ]


class MockDatabaseData:
    """Mock database responses for testing"""

    @staticmethod
    def get_mock_session():
        """Create a mock database session"""
        from unittest.mock import MagicMock
        session = MagicMock()
        session.execute.return_value.fetchall.return_value = []
        session.execute.return_value.fetchone.return_value = None
        session.commit.return_value = None
        session.rollback.return_value = None
        return session

    @staticmethod
    def get_mock_engine():
        """Create a mock database engine"""
        from unittest.mock import MagicMock
        engine = MagicMock()
        engine.connect.return_value.__enter__.return_value = MagicMock()
        return engine


class TestHelpers:
    """Helper functions for tests"""

    @staticmethod
    def create_s3_event(bucket: str, key: str) -> Dict[str, Any]:
        """Create a mock S3 event"""
        return {
            'Records': [{
                's3': {
                    'bucket': {'name': bucket},
                    'object': {'key': key}
                }
            }]
        }

    @staticmethod
    def create_sqs_message(body: Dict[str, Any]) -> Dict[str, Any]:
        """Create a mock SQS message"""
        return {
            'Records': [{
                'messageId': 'test-message-id',
                'body': json.dumps(body)
            }]
        }

    @staticmethod
    def create_api_gateway_event(
        path: str,
        method: str,
        body: Dict[str, Any] = None,
        headers: Dict[str, str] = None
    ) -> Dict[str, Any]:
        """Create a mock API Gateway event"""
        return {
            'httpMethod': method,
            'path': path,
            'headers': headers or {},
            'body': json.dumps(body) if body else None,
            'queryStringParameters': None
        }


# Export all fixture classes
__all__ = [
    'SampleTaxonomyData',
    'SampleProfessionData',
    'SampleMappingData',
    'SampleTranslationData',
    'SampleProcessingData',
    'MockDatabaseData',
    'TestHelpers'
]