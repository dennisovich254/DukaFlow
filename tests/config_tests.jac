"""P0.3: configuration loading and validation."""

import from config.settings { load_settings, ConfigError }

test "missing required variable names the variable" {
    with testraises(ConfigError) as e {
        load_settings({}, required=["GEMINI_API_KEY"]);
    }
    assert "GEMINI_API_KEY" in str(e.value);
}

test "all required variables present loads" {
    settings = load_settings({"GEMINI_API_KEY": "k"}, required=["GEMINI_API_KEY"]);
    assert settings.max_image_bytes == 5242880;
}

test "defaults apply when optional variables are absent" {
    settings = load_settings({}, required=[]);
    assert settings.app_env == "development";
    assert settings.timezone == "Africa/Nairobi";
    assert settings.max_image_bytes == 5242880;
    assert settings.ai_mode == "live";
    assert settings.media_storage_dir.endswith("/.local/share/dukaflow/media");
    assert not settings.media_storage_dir.startswith("~");
}

test "non numeric image limit is rejected" {
    with testraises(ConfigError) as e {
        load_settings({"MAX_IMAGE_BYTES": "5MB"}, required=[]);
    }
    assert "MAX_IMAGE_BYTES" in str(e.value);
}

test "unknown ai mode is rejected" {
    with testraises(ConfigError) as e {
        load_settings({"AI_MODE": "turbo"}, required=[]);
    }
    assert "AI_MODE" in str(e.value);
}

test "mock mode and custom media dir are accepted" {
    settings = load_settings({"AI_MODE": "mock", "MEDIA_STORAGE_DIR": "/tmp/dukaflow-media"}, required=[]);
    assert settings.ai_mode == "mock";
    assert settings.media_storage_dir == "/tmp/dukaflow-media";
}
