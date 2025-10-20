/**
 * Database Connection Management
 * PostgreSQL connection pool and transaction utilities
 */

import { Pool, PoolClient, PoolConfig } from 'pg';

/**
 * Create database connection pool from environment variables
 */
export function createDatabasePool(): Pool {
  const config: PoolConfig = {
    host: process.env.PGHOST || 'localhost',
    port: parseInt(process.env.PGPORT || '5432', 10),
    database: process.env.PGDATABASE || 'taxonomy',
    user: process.env.PGUSER || 'lambda_user',
    password: process.env.PGPASSWORD,
    ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: false } : false,
    max: 2, // Lambda: low connection count, scales via concurrent executions
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  };

  // Set search_path to use taxonomy_schema
  const pool = new Pool(config);

  // Execute SET search_path on each new connection
  pool.on('connect', async (client) => {
    try {
      await client.query(`SET search_path = ${process.env.PGSCHEMA || 'taxonomy_schema'}, public`);
    } catch (err) {
      console.error('Error setting search_path:', err);
    }
  });

  return pool;
}

/**
 * Execute function within a transaction
 * Automatically handles BEGIN, COMMIT, and ROLLBACK
 */
export async function withTransaction<T>(
  pool: Pool,
  callback: (client: PoolClient) => Promise<T>
): Promise<T> {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
