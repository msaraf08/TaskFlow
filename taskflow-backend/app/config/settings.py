from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "TaskFlow"
    app_env: str = "development"

    mongodb_url: str = "mongodb://localhost:27017"
    mongodb_database: str = "taskflow"

    redis_url: str = "redis://localhost:6379"

    jwt_secret: str = "supersecretkey"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30

    model_config = SettingsConfigDict(
        env_file=(".env", "taskflow-backend/.env"),
        extra="ignore"
    )


settings = Settings()