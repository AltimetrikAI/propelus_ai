"""
Unit tests for Bronze Layer Ingestion Lambda Handler
Tests data ingestion, parsing, and storage functionality
"""

import json
import pytest
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime
import pandas as pd
from io import StringIO, BytesIO
import os
import sys

# Add the lambdas directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../lambdas'))

from bronze_ingestion.handler import (
    handler,
    process_s3_event,
    parse_csv_file,
    parse_json_file,
    parse_excel_file,
    store_bronze_data,
    validate_data_quality,
    create_source_record,
    trigger_silver_processing
)


class TestBronzeIngestionHandler:
    """Test suite for Bronze ingestion Lambda handler"""

    @pytest.fixture
    def mock_s3_event(self):
        """Create a mock S3 event"""
        return {
            'Records': [{
                's3': {
                    'bucket': {
                        'name': 'test-bronze-bucket'
                    },
                    'object': {
                        'key': 'customer1/taxonomies/2024/09/data.csv'
                    }
                }
            }]
        }

    @pytest.fixture
    def mock_context(self):
        """Create a mock Lambda context"""
        context = Mock()
        context.request_id = 'test-request-123'
        context.function_name = 'bronze-ingestion'
        context.memory_limit_in_mb = 1024
        return context

    @pytest.fixture
    def sample_csv_data(self):
        """Sample CSV data for testing"""
        return """profession_code,profession_name,state,license_type
RN,Registered Nurse,CA,Active
MD,Medical Doctor,NY,Active
PT,Physical Therapist,TX,Inactive"""

    @pytest.fixture
    def sample_json_data(self):
        """Sample JSON data for testing"""
        return {
            "taxonomies": [
                {
                    "id": "1",
                    "name": "Healthcare Providers",
                    "nodes": [
                        {"id": "101", "value": "Nurses", "level": 1},
                        {"id": "102", "value": "Doctors", "level": 1}
                    ]
                }
            ]
        }

    def test_handler_with_s3_event(self, mock_s3_event, mock_context):
        """Test handler processing S3 event"""
        with patch('bronze_ingestion.handler.process_s3_event') as mock_process:
            mock_process.return_value = {'status': 'success', 'records_processed': 10}

            result = handler(mock_s3_event, mock_context)

            assert result['statusCode'] == 200
            assert 'results' in json.loads(result['body'])
            mock_process.assert_called_once()

    def test_handler_direct_invocation(self, mock_context):
        """Test handler with direct invocation"""
        event = {
            'source_type': 'manual',
            'customer_id': 1,
            'data_type': 'taxonomies',
            'file_content': 'test_content'
        }

        with patch('bronze_ingestion.handler.process_direct_upload') as mock_process:
            mock_process.return_value = {'status': 'success', 'source_id': 123}

            result = handler(event, mock_context)

            assert result['statusCode'] == 200
            assert json.loads(result['body'])['source_id'] == 123

    def test_parse_csv_file(self, sample_csv_data):
        """Test CSV parsing functionality"""
        with patch('bronze_ingestion.handler.s3_client.get_object') as mock_s3:
            mock_s3.return_value = {
                'Body': MagicMock(read=lambda: sample_csv_data.encode())
            }

            result = parse_csv_file('test-bucket', 'test-key.csv')

            assert len(result) == 3
            assert result[0]['profession_code'] == 'RN'
            assert result[1]['profession_name'] == 'Medical Doctor'
            assert result[2]['state'] == 'TX'

    def test_parse_json_file(self, sample_json_data):
        """Test JSON parsing functionality"""
        with patch('bronze_ingestion.handler.s3_client.get_object') as mock_s3:
            mock_s3.return_value = {
                'Body': MagicMock(read=lambda: json.dumps(sample_json_data).encode())
            }

            result = parse_json_file('test-bucket', 'test-key.json')

            assert 'taxonomies' in result
            assert len(result['taxonomies']) == 1
            assert result['taxonomies'][0]['name'] == 'Healthcare Providers'
            assert len(result['taxonomies'][0]['nodes']) == 2

    @patch('bronze_ingestion.handler.pd.read_excel')
    def test_parse_excel_file(self, mock_read_excel):
        """Test Excel parsing functionality"""
        mock_df = pd.DataFrame({
            'code': ['RN', 'MD'],
            'description': ['Registered Nurse', 'Medical Doctor']
        })
        mock_read_excel.return_value = mock_df

        with patch('bronze_ingestion.handler.s3_client.get_object') as mock_s3:
            mock_s3.return_value = {
                'Body': MagicMock(read=lambda: b'mock_excel_content')
            }

            result = parse_excel_file('test-bucket', 'test-key.xlsx')

            assert len(result) == 2
            assert result[0]['code'] == 'RN'
            assert result[1]['description'] == 'Medical Doctor'

    @patch('bronze_ingestion.handler.Session')
    def test_store_bronze_data_taxonomies(self, mock_session):
        """Test storing taxonomy data in bronze layer"""
        mock_db = MagicMock()
        mock_session.return_value.__enter__.return_value = mock_db

        test_data = [
            {'id': '1', 'name': 'Nursing', 'type': 'profession_group'}
        ]

        result = store_bronze_data(
            source_id=1,
            data=test_data,
            data_type='taxonomies'
        )

        assert result['records_stored'] == 1
        assert result['table'] == 'bronze_taxonomies'
        mock_db.execute.assert_called()

    @patch('bronze_ingestion.handler.Session')
    def test_store_bronze_data_professions(self, mock_session):
        """Test storing profession data in bronze layer"""
        mock_db = MagicMock()
        mock_session.return_value.__enter__.return_value = mock_db

        test_data = [
            {'code': 'RN', 'name': 'Registered Nurse', 'state': 'CA'}
        ]

        result = store_bronze_data(
            source_id=1,
            data=test_data,
            data_type='professions'
        )

        assert result['records_stored'] == 1
        assert result['table'] == 'bronze_professions'

    def test_validate_data_quality_valid(self):
        """Test data quality validation with valid data"""
        valid_data = [
            {'profession_code': 'RN', 'profession_name': 'Registered Nurse'},
            {'profession_code': 'MD', 'profession_name': 'Medical Doctor'}
        ]

        result = validate_data_quality(valid_data, 'professions')

        assert result['is_valid'] == True
        assert result['error_count'] == 0
        assert len(result['warnings']) == 0

    def test_validate_data_quality_invalid(self):
        """Test data quality validation with invalid data"""
        invalid_data = [
            {'profession_code': '', 'profession_name': 'Registered Nurse'},  # Missing code
            {'profession_code': 'MD'},  # Missing name
            None,  # Null record
            {}  # Empty record
        ]

        result = validate_data_quality(invalid_data, 'professions')

        assert result['is_valid'] == False
        assert result['error_count'] > 0
        assert len(result['validation_errors']) > 0

    @patch('bronze_ingestion.handler.Session')
    def test_create_source_record(self, mock_session):
        """Test creating source record"""
        mock_db = MagicMock()
        mock_session.return_value.__enter__.return_value = mock_db
        mock_db.execute.return_value.fetchone.return_value = [123]

        result = create_source_record(
            customer_id=1,
            source_type='csv',
            source_name='test_upload.csv',
            metadata={'rows': 100, 'columns': 5}
        )

        assert result == 123
        mock_db.execute.assert_called()
        mock_db.commit.assert_called()

    @patch('bronze_ingestion.handler.sqs_client.send_message')
    def test_trigger_silver_processing(self, mock_sqs):
        """Test triggering Silver layer processing"""
        mock_sqs.return_value = {
            'MessageId': 'test-message-123',
            'ResponseMetadata': {'HTTPStatusCode': 200}
        }

        result = trigger_silver_processing(source_id=123)

        assert result == True
        mock_sqs.assert_called_once()
        call_args = mock_sqs.call_args[1]
        assert 'QueueUrl' in call_args
        message_body = json.loads(call_args['MessageBody'])
        assert message_body['source_id'] == 123

    def test_extract_customer_id_from_s3_key(self):
        """Test extracting customer ID from S3 key"""
        from bronze_ingestion.handler import extract_customer_id_from_key

        # Test various key formats
        assert extract_customer_id_from_key('customer1/data.csv') == 1
        assert extract_customer_id_from_key('customer_123/taxonomies/data.json') == 123
        assert extract_customer_id_from_key('client-5/upload.xlsx') == 5
        assert extract_customer_id_from_key('unknown/data.csv') == None

    @patch('bronze_ingestion.handler.Session')
    def test_handle_duplicate_data(self, mock_session):
        """Test handling of duplicate data"""
        mock_db = MagicMock()
        mock_session.return_value.__enter__.return_value = mock_db

        # Simulate duplicate key error
        from sqlalchemy.exc import IntegrityError
        mock_db.execute.side_effect = IntegrityError("duplicate", "params", "orig")

        with pytest.raises(IntegrityError):
            store_bronze_data(
                source_id=1,
                data=[{'id': '1', 'name': 'Test'}],
                data_type='taxonomies'
            )

    def test_error_handling_invalid_file_format(self):
        """Test error handling for unsupported file formats"""
        event = {
            'Records': [{
                's3': {
                    'bucket': {'name': 'test-bucket'},
                    'object': {'key': 'test.unknown'}
                }
            }]
        }

        with patch('bronze_ingestion.handler.process_s3_event') as mock_process:
            mock_process.side_effect = ValueError("Unsupported file format")

            result = handler(event, Mock())

            assert result['statusCode'] == 500
            assert 'error' in json.loads(result['body'])

    @pytest.mark.parametrize("file_size,expected", [
        (1024, True),  # 1KB - should process
        (10 * 1024 * 1024, True),  # 10MB - should process
        (100 * 1024 * 1024, False),  # 100MB - should reject
    ])
    def test_file_size_validation(self, file_size, expected):
        """Test file size validation"""
        from bronze_ingestion.handler import validate_file_size

        assert validate_file_size(file_size) == expected


class TestDataTransformations:
    """Test data transformation functions"""

    def test_normalize_state_codes(self):
        """Test state code normalization"""
        from bronze_ingestion.handler import normalize_state_code

        assert normalize_state_code('california') == 'CA'
        assert normalize_state_code('CA') == 'CA'
        assert normalize_state_code('cal') == 'CA'
        assert normalize_state_code('unknown') == None

    def test_clean_profession_code(self):
        """Test profession code cleaning"""
        from bronze_ingestion.handler import clean_profession_code

        assert clean_profession_code('  RN  ') == 'RN'
        assert clean_profession_code('r.n.') == 'RN'
        assert clean_profession_code('MD-001') == 'MD001'
        assert clean_profession_code('') == None

    def test_standardize_date_format(self):
        """Test date standardization"""
        from bronze_ingestion.handler import standardize_date

        assert standardize_date('2024-09-26') == '2024-09-26'
        assert standardize_date('09/26/2024') == '2024-09-26'
        assert standardize_date('26-Sep-2024') == '2024-09-26'
        assert standardize_date('invalid') == None


if __name__ == '__main__':
    pytest.main([__file__, '-v'])