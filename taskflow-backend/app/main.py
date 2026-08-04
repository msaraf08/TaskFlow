from fastapi import FastAPI

app = FastAPI(
    title="TaskFlow API",
    version="1.0.0"
)


@app.get("/")
async def root():
    return {
        "message": "Welcome to TaskFlow API 🚀"
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy"
    }