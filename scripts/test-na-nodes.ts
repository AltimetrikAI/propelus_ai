/**
 * N/A Node Testing Script
 *
 * Tests the N/A node implementation with real database operations
 *
 * Usage: npm run test:na-nodes
 */

import { Pool } from 'pg';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Simple test runner
class TestRunner {
  private pool: Pool;
  private testsPassed = 0;
  private testsFailed = 0;

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'propelus_taxonomy',
      user: process.env.DB_USER || 'propelus_admin',
      password: process.env.DB_PASSWORD
    });
  }

  async test(name: string, fn: () => Promise<void>): Promise<void> {
    try {
      await fn();
      this.testsPassed++;
      console.log(`✓ ${name}`);
    } catch (error) {
      this.testsFailed++;
      console.error(`✗ ${name}`);
      console.error(`  Error: ${error.message}`);
    }
  }

  async runTests(): Promise<void> {
    console.log('\n🧪 Testing N/A Node Implementation\n');
    console.log('='.repeat(70));

    // Test 1: Check N/A node type exists
    await this.test('N/A node type exists in database', async () => {
      const result = await this.pool.query(`
        SELECT * FROM silver_taxonomies_nodes_types
        WHERE node_type_id = -1 AND name = 'N/A'
      `);
      if (result.rows.length === 0) {
        throw new Error('N/A node type not found');
      }
    });

    // Test 2: Check SQL functions exist
    await this.test('SQL helper functions exist', async () => {
      const functions = [
        'get_node_full_path',
        'get_node_display_path',
        'get_active_children'
      ];

      for (const fn of functions) {
        const result = await this.pool.query(`
          SELECT 1 FROM pg_proc WHERE proname = $1
        `, [fn]);

        if (result.rows.length === 0) {
          throw new Error(`Function ${fn} not found`);
        }
      }
    });

    // Test 3: Check indexes exist
    await this.test('Performance indexes exist', async () => {
      const result = await this.pool.query(`
        SELECT indexname FROM pg_indexes
        WHERE indexname IN ('idx_nodes_exclude_na', 'idx_nodes_na_only')
      `);

      if (result.rows.length < 2) {
        throw new Error('Required indexes not found');
      }
    });

    console.log('='.repeat(70));
    console.log(`\n📊 Results: ${this.testsPassed} passed, ${this.testsFailed} failed\n`);

    if (this.testsFailed > 0) {
      process.exit(1);
    }
  }

  async cleanup(): Promise<void> {
    await this.pool.end();
  }
}

// Run tests
const runner = new TestRunner();
runner.runTests()
  .then(() => runner.cleanup())
  .then(() => {
    console.log('✅ All tests completed successfully!\n');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Test suite failed:', error);
    runner.cleanup();
    process.exit(1);
  });
