"""P3.2: photo validation and storage."""

import os;
import tempfile;
import from integrations.media { store_chat_image, media_path }
import from domain.errors { DomainError }
import from tests.helpers { code_of }

def sample_bytes() -> bytes {
    with open("tests/fixtures/images/sample_list.jpg", "rb") as f {
        return f.read();
    }
}

test "a real jpeg is stored under a random name" {
    d = tempfile.mkdtemp();
    ref = store_chat_image(sample_bytes(), "image/jpeg", "list.jpg", d, 5242880);
    assert ref.endswith(".jpg") and os.path.exists(media_path(d, ref));
    assert ref != store_chat_image(sample_bytes(), "image/jpeg", "list.jpg", d, 5242880);
}

test "a pdf, fake jpg and mismatched types are rejected and nothing is written" {
    d = tempfile.mkdtemp();
    with testraises(DomainError) as e1 { store_chat_image(b"%PDF-1.4 x", "application/pdf", "a.pdf", d, 5242880); }
    assert code_of(e1.value) == "UNSUPPORTED_MEDIA";
    with testraises(DomainError) as e2 { store_chat_image(b"not an image at all", "image/jpeg", "a.jpg", d, 5242880); }
    assert code_of(e2.value) == "UNSUPPORTED_MEDIA";
    png = b"\x89PNG\r\n\x1a\n" + b"0" * 20;
    with testraises(DomainError) as e3 { store_chat_image(png, "image/jpeg", "a.jpg", d, 5242880); }
    assert code_of(e3.value) == "UNSUPPORTED_MEDIA" and os.listdir(d) == [];
    assert store_chat_image(png, "image/png", "a.png", d, 5242880).endswith(".png");
}

test "oversized photos are rejected" {
    d = tempfile.mkdtemp();
    with testraises(DomainError) as e { store_chat_image(sample_bytes(), "image/jpeg", "a.jpg", d, 100); }
    assert code_of(e.value) == "MEDIA_TOO_LARGE" and os.listdir(d) == [];
}

test "media_path refuses path traversal" {
    with testraises(DomainError) as e { media_path("media", "../secret.jpg"); }
    assert code_of(e.value) == "VALIDATION_ERROR";
}
