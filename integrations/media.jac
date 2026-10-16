"""Chat photo validation and storage. Nothing from the client is trusted: the declared
type must match the file's magic bytes, size is capped, and files are saved under a
random name inside the storage directory."""

import os;
import secrets;
import from domain.errors { DomainError }

glob ALLOWED_TYPES: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp"
};

def detect_image_type(data: bytes) -> str {
    if data[:3] == b"\xff\xd8\xff" { return "image/jpeg"; }
    if data[:8] == b"\x89PNG\r\n\x1a\n" { return "image/png"; }
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP" { return "image/webp"; }
    return "";
}

"""Validate and save an image; returns the `media_ref` (file name inside the storage dir)."""
def store_chat_image(
    data: bytes, mime_type: str, filename: str, storage_dir: str, max_bytes: int
) -> str {
    if mime_type not in ALLOWED_TYPES {
        raise DomainError(code="UNSUPPORTED_MEDIA", message=f"{mime_type or 'That file type'} is not supported. Send a JPEG, PNG or WebP photo.");
    }
    if len(data) == 0 {
        raise DomainError(code="UNSUPPORTED_MEDIA", message="The photo is empty.");
    }
    if len(data) > max_bytes {
        raise DomainError(code="MEDIA_TOO_LARGE", message=f"The photo is larger than {max_bytes // 1048576} MB.");
    }
    if detect_image_type(data) != mime_type {
        raise DomainError(code="UNSUPPORTED_MEDIA", message="The file is not a real image of the declared type.");
    }
    os.makedirs(storage_dir, exist_ok=True);
    media_ref = secrets.token_hex(16) + ALLOWED_TYPES[mime_type];
    with open(os.path.join(storage_dir, media_ref), "wb") as f {
        f.write(data);
    }
    return media_ref;
}

"""Path for a stored image, refusing anything that is not a plain file name."""
def media_path(storage_dir: str, media_ref: str) -> str {
    if not media_ref or media_ref != os.path.basename(media_ref) {
        raise DomainError(code="VALIDATION_ERROR", message="Invalid media reference");
    }
    return os.path.join(storage_dir, media_ref);
}
