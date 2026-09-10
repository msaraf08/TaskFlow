from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "TaskFlow"
    app_env: str = "development"

    mongodb_url: str = "mongodb://localhost:27017"
    mongodb_database: str = "taskflow"

    redis_url: str = "redis://localhost:6379/0"
    redis_host: str | None = None
    redis_port: int | None = None
    redis_db: int | None = None

    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30

    cors_origins: list[str] = [
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:8080",
    ]
    cors_origin_regex: str | None = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    model_config = SettingsConfigDict(
        env_file=(".env", "taskflow-backend/.env"),
        extra="ignore"
    )


settings = Settings()