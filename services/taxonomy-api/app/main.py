"""
Taxonomy API Service
Main FastAPI application for managing healthcare profession taxonomy
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
import structlog
import time
from prometheus_client import make_asgi_app

from app.core.config import settings
from app.core.database import engine, Base
from app.core.logging import setup_logging
from app.api.v1.router import api_router
from app.middleware.request_id import RequestIDMiddleware
from app.middleware.logging import LoggingMiddleware

# Setup structured logging
setup_logging()
logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifecycle"""
    logger.info("Starting Taxonomy API Service", version=settings.VERSION)
    
    # Initialize database
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Initialize cache connection
    # await init_redis()
    
    yield
    
    # Cleanup
    logger.info("Shutting down Taxonomy API Service")
    await engine.dispose()

# Create FastAPI application
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Healthcare Profession Taxonomy Management System",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add middleware
app.add_middleware(RequestIDMiddleware)
app.add_middleware(LoggingMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.ALLOWED_HOSTS
)

# Include routers
app.include_router(api_router, prefix=settings.API_V1_STR)

# Mount metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION
    }

@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint"""
    try:
        # Check database connection
        async with engine.connect() as conn:
            await conn.execute("SELECT 1")
        
        return {
            "status": "ready",
            "service": settings.PROJECT_NAME,
            "checks": {
                "database": "healthy",
                "cache": "healthy"
            }
        }
    except Exception as e:
        logger.error("Readiness check failed", error=str(e))
        return JSONResponse(
            status_code=503,
            content={
                "status": "not_ready",
                "error": str(e)
            }
        )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler"""
    logger.error(
        "Unhandled exception",
        error=str(exc),
        path=request.url.path,
        method=request.method
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "request_id": request.state.request_id if hasattr(request.state, "request_id") else None
        }
    )