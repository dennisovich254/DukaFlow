"""Application configuration loaded from environment variables."""

import os;

glob DEFAULT_MAX_IMAGE_BYTES: int = 5242880;
# Outside the project tree on purpose: the dev server watches the project folder and
# restarts when files appear in it, which would disturb every photo upload.
glob DEFAULT_MEDIA_DIR: str = "~/.local/share/dukaflow/media";
glob AI_MODES: list[str] = ["live", "mock"];

"""Raised when required configuration is missing or invalid."""
obj ConfigError(Exception) {}

"""Typed application settings. Secrets are never logged."""
obj Settings {
    has app_env: str = "development",
        app_base_url: str = "",
        timezone: str = "Africa/Nairobi",
        ai_mode: str = "live",
        media_storage_dir: str = "~/.local/share/dukaflow/media",
        max_image_bytes: int = 5242880;
}

"""Build Settings from `env`, failing clearly if any `required` name is absent."""
def load_settings(env: dict[str, str], required: list[str]) -> Settings {
    missing = [name for name in required if not env.get(name, "")];
    if missing {
        raise ConfigError(
            f"Missing required configuration: {', '.join(missing)}"
        );
    }
    raw_limit = env.get("MAX_IMAGE_BYTES", str(DEFAULT_MAX_IMAGE_BYTES));
    if not raw_limit.isdigit() {
        raise ConfigError(
            f"MAX_IMAGE_BYTES must be a whole number of bytes, got '{raw_limit}'"
        );
    }
    ai_mode = env.get("AI_MODE", "live");
    if ai_mode not in AI_MODES {
        raise ConfigError(f"AI_MODE must be one of {', '.join(AI_MODES)}, got '{ai_mode}'");
    }
    media_dir = env.get("MEDIA_STORAGE_DIR", "") or DEFAULT_MEDIA_DIR;
    return Settings(
        app_env=env.get("APP_ENV", "development"),
        app_base_url=env.get("APP_BASE_URL", ""),
        timezone=env.get("APP_TIMEZONE", "Africa/Nairobi"),
        ai_mode=ai_mode,
        media_storage_dir=os.path.expanduser(media_dir),
        max_image_bytes=int(raw_limit)
    );
}

"""Load settings from the process environment."""
def settings_from_env(required: list[str]) -> Settings {
    return load_settings(dict(os.environ), required);
}
