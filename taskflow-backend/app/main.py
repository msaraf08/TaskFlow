from fastapi import FastAPI
from app.config.settings import settings
from app.database.mongodb import client

app = FastAPI(
    title=settings.app_name,
    version="1.0.0"
)


@app.on_event("startup")
async def startup_event():
    # Test MongoDB connection on startup
    try:
        await client.server_info()  # This will raise an exception if the connection fails
        print("Connected to MongoDB successfully.")
    except Exception as e:
        print(f"Failed to connect to MongoDB: {e}")


@app.on_event("shutdown")
async def shutdown_event():
    # Close MongoDB connection on shutdown
    await client.close()
    print("MongoDB connection closed.")


@app.get("/")
async def root():
    return {
        "message": f"Welcome to {settings.app_name}🚀"
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "environment": settings.app_env
    }