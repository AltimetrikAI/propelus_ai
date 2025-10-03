/**
 * Local Test Runner for Ingestion & Cleansing Lambda
 *
 * Runs the Lambda handler locally with test data for development and testing.
 */

import * as fs from 'fs';
import * as path from 'path';
import { handler } from '../src/handler';
import { sampleApiEvents, sampleS3Events } from './sample-data-generator';

// ============================================
// Test Configuration
// ============================================

interface TestConfig {
  eventType: 'api' | 's3';
  eventName: string;
  testDataDir: string;
}

// ============================================
// Test Runner
// ============================================

async function runTest(config: TestConfig): Promise<void> {
  console.log('🧪 Starting Lambda Test Run');
  console.log('━'.repeat(60));
  console.log(`Event Type: ${config.eventType}`);
  console.log(`Event Name: ${config.eventName}`);
  console.log(`Test Data Dir: ${config.testDataDir}`);
  console.log('━'.repeat(60));
  console.log('');

  // Load event
  let event: any;

  if (config.eventType === 'api') {
    // Load from sample API events
    event = (sampleApiEvents as any)[config.eventName];
    if (!event) {
      console.error(`❌ API event "${config.eventName}" not found`);
      console.log('Available events:', Object.keys(sampleApiEvents));
      process.exit(1);
    }
  } else {
    // Load from sample S3 events
    event = (sampleS3Events as any)[config.eventName];
    if (!event) {
      console.error(`❌ S3 event "${config.eventName}" not found`);
      console.log('Available events:', Object.keys(sampleS3Events));
      process.exit(1);
    }

    // Note: For S3 events, the actual file reading is handled by the Lambda
    // In a real test, you'd need to mock the S3 client or upload to actual S3
    console.warn(
      '⚠️  WARNING: S3 events require actual S3 bucket access or mocked S3 client'
    );
    console.warn(
      '⚠️  For full testing, upload Excel files to S3 or mock @aws-sdk/client-s3'
    );
    console.log('');
  }

  // Display event
  console.log('📋 Event Payload:');
  console.log(JSON.stringify(event, null, 2));
  console.log('');

  // Check database connection
  console.log('🔌 Checking database connection...');
  const dbEnvVars = ['PGHOST', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD'];
  const missingVars = dbEnvVars.filter(v => !process.env[v]);

  if (missingVars.length > 0) {
    console.error('❌ Missing required environment variables:');
    missingVars.forEach(v => console.error(`   - ${v}`));
    console.log('');
    console.log('Set environment variables:');
    console.log('   export PGHOST=localhost');
    console.log('   export PGPORT=5432');
    console.log('   export PGDATABASE=propelus_taxonomy');
    console.log('   export PGUSER=postgres');
    console.log('   export PGPASSWORD=your_password');
    process.exit(1);
  }

  console.log('✅ Database configuration found');
  console.log('');

  // Run handler
  console.log('🚀 Executing Lambda handler...');
  console.log('━'.repeat(60));
  console.log('');

  try {
    const startTime = Date.now();
    const result = await handler(event);
    const duration = Date.now() - startTime;

    console.log('');
    console.log('━'.repeat(60));
    console.log('✅ Lambda execution completed successfully');
    console.log('━'.repeat(60));
    console.log('');

    console.log('📊 Result:');
    console.log(JSON.stringify(result, null, 2));
    console.log('');

    console.log('⏱️  Execution Time:', `${duration}ms`);
    console.log('');

    // Display verification queries
    if (result.ok && result.load_id) {
      console.log('🔍 Verification Queries:');
      console.log('');
      console.log('-- Check load details');
      console.log(`SELECT * FROM bronze_load_details WHERE load_id = ${result.load_id};`);
      console.log('');
      console.log('-- Check created nodes');
      console.log(`SELECT COUNT(*) FROM silver_taxonomies_nodes WHERE load_id = ${result.load_id};`);
      console.log('');
      console.log('-- Check attributes');
      console.log(`SELECT COUNT(*) FROM silver_taxonomies_nodes_attributes WHERE load_id = ${result.load_id};`);
      console.log('');
      console.log('-- Check version');
      console.log(`SELECT * FROM silver_taxonomies_versions WHERE taxonomy_id = '${result.taxonomy_id}';`);
      console.log('');
      console.log('-- View sample nodes');
      console.log(`SELECT node_id, value, level, status, profession FROM silver_taxonomies_nodes WHERE load_id = ${result.load_id} LIMIT 10;`);
      console.log('');
    }
  } catch (error: any) {
    console.log('');
    console.log('━'.repeat(60));
    console.error('❌ Lambda execution failed');
    console.log('━'.repeat(60));
    console.log('');

    console.error('Error:', error.message);

    if (error.stack) {
      console.log('');
      console.log('Stack Trace:');
      console.error(error.stack);
    }

    console.log('');
    console.log('💡 Troubleshooting Tips:');
    console.log('   1. Verify database is running and accessible');
    console.log('   2. Check that migrations have been run (tables exist)');
    console.log('   3. Verify environment variables are set correctly');
    console.log('   4. For S3 events, ensure files exist in S3 or mock S3 client');
    console.log('   5. Check Lambda handler logs for detailed error messages');

    process.exit(1);
  }
}

// ============================================
// CLI Interface
// ============================================

async function main() {
  const args = process.argv.slice(2);

  // Display help
  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log('Local Test Runner for Ingestion & Cleansing Lambda');
    console.log('');
    console.log('Usage:');
    console.log('  npm run test:local [eventType] [eventName] [testDataDir]');
    console.log('');
    console.log('Examples:');
    console.log('  npm run test:local api masterSocialWork');
    console.log('  npm run test:local api masterNursePractitioners');
    console.log('  npm run test:local api customerHospitalA');
    console.log('  npm run test:local s3 masterSocialWork');
    console.log('');
    console.log('Available API Events:');
    Object.keys(sampleApiEvents).forEach(name => {
      console.log(`  - ${name}`);
    });
    console.log('');
    console.log('Available S3 Events:');
    Object.keys(sampleS3Events).forEach(name => {
      console.log(`  - ${name}`);
    });
    console.log('');
    console.log('Environment Variables Required:');
    console.log('  PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD');
    console.log('');
    return;
  }

  // Parse arguments
  const eventType = (args[0] || 'api') as 'api' | 's3';
  const eventName = args[1] || 'masterSocialWork';
  const testDataDir = args[2] || './test-data';

  // Validate event type
  if (!['api', 's3'].includes(eventType)) {
    console.error(`❌ Invalid event type: ${eventType}`);
    console.log('Must be "api" or "s3"');
    process.exit(1);
  }

  // Run test
  await runTest({
    eventType,
    eventName,
    testDataDir
  });
}

// ============================================
// Entry Point
// ============================================

if (require.main === module) {
  main().catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { runTest };
