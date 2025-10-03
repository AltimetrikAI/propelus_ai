/**
 * Structured Logging Utility
 */

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
}

interface LogContext {
  [key: string]: any;
}

class Logger {
  private context: LogContext;

  constructor(context: LogContext = {}) {
    this.context = context;
  }

  private log(level: LogLevel, message: string, meta: LogContext = {}) {
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...this.context,
      ...meta,
    };

    const logString = JSON.stringify(logEntry);

    switch (level) {
      case LogLevel.DEBUG:
      case LogLevel.INFO:
        console.log(logString);
        break;
      case LogLevel.WARN:
        console.warn(logString);
        break;
      case LogLevel.ERROR:
        console.error(logString);
        break;
    }
  }

  debug(message: string, meta: LogContext = {}) {
    this.log(LogLevel.DEBUG, message, meta);
  }

  info(message: string, meta: LogContext = {}) {
    this.log(LogLevel.INFO, message, meta);
  }

  warn(message: string, meta: LogContext = {}) {
    this.log(LogLevel.WARN, message, meta);
  }

  error(message: string, error?: Error | string, meta: LogContext = {}) {
    const errorMeta = error instanceof Error ? { error: error.message, stack: error.stack } : { error };
    this.log(LogLevel.ERROR, message, { ...meta, ...errorMeta });
  }

  child(additionalContext: LogContext): Logger {
    return new Logger({ ...this.context, ...additionalContext });
  }
}

export function createLogger(context: LogContext = {}): Logger {
  return new Logger(context);
}

export default Logger;
