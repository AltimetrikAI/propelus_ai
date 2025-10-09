/**
 * Database Migration Runner
 * Executes SQL migration files in order
 *
 * Usage:
 *   npm run migrate              # Run all pending migrations
 *   npm run migrate:rollback     # Rollback last migration
 */

import { Pool } from 'pg';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

interface MigrationFile {
  number: number;
  name: string;
  filename: string;
  path: string;
}

interface MigrationRecord {
  migration_number: number;
  migration_name: string;
  executed_at: Date;
}

class MigrationRunner {
  private pool: Pool;
  private migrationsDir: string;

  constructor() {
    this.pool = new Pool({
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'propelus_taxonomy',
      user: process.env.DB_USER || 'propelus_admin',
      password: process.env.DB_PASSWORD
    });

    this.migrationsDir = path.join(__dirname, 'migrations');
  }

  /**
   * Initialize migrations tracking table
   */
  private async initMigrationsTable(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        migration_number INTEGER PRIMARY KEY,
        migration_name TEXT NOT NULL,
        executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    console.log('✓ Migrations tracking table initialized\n');
  }

  /**
   * Get list of available migration files
   */
  private getMigrationFiles(): MigrationFile[] {
    const files = fs.readdirSync(this.migrationsDir)
      .filter(f => f.endsWith('.sql') && /^\d{3}-/.test(f))
      .sort();

    return files.map(filename => {
      const match = filename.match(/^(\d{3})-(.+)\.sql$/);
      if (!match) throw new Error(`Invalid migration filename: ${filename}`);

      return {
        number: parseInt(match[1]),
        name: match[2],
        filename,
        path: path.join(this.migrationsDir, filename)
      };
    });
  }

  /**
   * Get executed migrations from database
   */
  private async getExecutedMigrations(): Promise<MigrationRecord[]> {
    const result = await this.pool.query<MigrationRecord>(`
      SELECT migration_number, migration_name, executed_at
      FROM schema_migrations
      ORDER BY migration_number
    `);

    return result.rows;
  }

  /**
   * Execute a single migration
   */
  private async executeMigration(migration: MigrationFile): Promise<void> {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`Running migration ${migration.number}: ${migration.name}`);
    console.log('='.repeat(70));

    // Read SQL file
    const sql = fs.readFileSync(migration.path, 'utf8');

    // Execute in a transaction
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Execute the migration SQL
      await client.query(sql);

      // Record migration
      await client.query(`
        INSERT INTO schema_migrations (migration_number, migration_name)
        VALUES ($1, $2)
        ON CONFLICT (migration_number) DO NOTHING
      `, [migration.number, migration.name]);

      await client.query('COMMIT');

      console.log(`\n✓ Migration ${migration.number} completed successfully`);
    } catch (error) {
      await client.query('ROLLBACK');
      console.error(`\n✗ Migration ${migration.number} failed:`, error.message);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Run all pending migrations
   */
  async runMigrations(): Promise<void> {
    try {
      console.log('🚀 Starting database migrations...\n');

      // Initialize tracking table
      await this.initMigrationsTable();

      // Get available and executed migrations
      const availableMigrations = this.getMigrationFiles();
      const executedMigrations = await this.getExecutedMigrations();
      const executedNumbers = new Set(executedMigrations.map(m => m.migration_number));

      // Find pending migrations
      const pendingMigrations = availableMigrations.filter(
        m => !executedNumbers.has(m.number)
      );

      if (pendingMigrations.length === 0) {
        console.log('✓ No pending migrations. Database is up to date.\n');
        return;
      }

      console.log(`Found ${pendingMigrations.length} pending migration(s):\n`);
      pendingMigrations.forEach(m => {
        console.log(`  ${m.number}. ${m.name}`);
      });
      console.log('');

      // Execute pending migrations
      for (const migration of pendingMigrations) {
        await this.executeMigration(migration);
      }

      console.log(`\n${'='.repeat(70)}`);
      console.log('✅ All migrations completed successfully!');
      console.log('='.repeat(70));
    } catch (error) {
      console.error('\n❌ Migration failed:', error);
      throw error;
    } finally {
      await this.pool.end();
    }
  }

  /**
   * Show migration status
   */
  async status(): Promise<void> {
    try {
      console.log('📊 Migration Status\n');

      await this.initMigrationsTable();

      const availableMigrations = this.getMigrationFiles();
      const executedMigrations = await this.getExecutedMigrations();
      const executedNumbers = new Set(executedMigrations.map(m => m.migration_number));

      console.log('Available migrations:');
      console.log('─'.repeat(70));
      console.log('  #  | Status    | Name');
      console.log('─'.repeat(70));

      availableMigrations.forEach(m => {
        const status = executedNumbers.has(m.number) ? '✓ Applied' : '⏳ Pending';
        console.log(`  ${m.number}  | ${status}  | ${m.name}`);
      });

      console.log('─'.repeat(70));
      console.log(`\nApplied: ${executedNumbers.size} | Pending: ${availableMigrations.length - executedNumbers.size}\n`);
    } catch (error) {
      console.error('❌ Failed to get status:', error);
      throw error;
    } finally {
      await this.pool.end();
    }
  }
}

// CLI Interface
const command = process.argv[2] || 'migrate';

const runner = new MigrationRunner();

switch (command) {
  case 'migrate':
    runner.runMigrations()
      .then(() => process.exit(0))
      .catch(() => process.exit(1));
    break;

  case 'status':
    runner.status()
      .then(() => process.exit(0))
      .catch(() => process.exit(1));
    break;

  default:
    console.error(`Unknown command: ${command}`);
    console.log('Usage:');
    console.log('  npm run migrate          # Run pending migrations');
    console.log('  npm run migrate:status   # Show migration status');
    process.exit(1);
}
