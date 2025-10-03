/**
 * Database Connection Configuration
 * TypeORM DataSource for PostgreSQL
 */
import { DataSource } from 'typeorm';
import { entities } from './entities';

export const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  username: process.env.DB_USER || 'propelus_admin',
  password: process.env.DB_PASSWORD || 'dev_password',
  database: process.env.DB_NAME || 'propelus_taxonomy',
  entities: entities,
  synchronize: false, // Don't auto-sync in production
  logging: process.env.DB_LOGGING === 'true',
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
  extra: {
    max: 20, // Maximum pool size
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  },
});

/**
 * Initialize database connection
 */
export async function initializeDatabase(): Promise<void> {
  try {
    await AppDataSource.initialize();
    console.log('Database connection initialized successfully');
  } catch (error) {
    console.error('Error initializing database connection:', error);
    throw error;
  }
}

/**
 * Close database connection
 */
export async function closeDatabase(): Promise<void> {
  if (AppDataSource.isInitialized) {
    await AppDataSource.destroy();
    console.log('Database connection closed');
  }
}

/**
 * Get a database repository
 */
export function getRepository<T>(entity: new () => T) {
  return AppDataSource.getRepository(entity);
}
