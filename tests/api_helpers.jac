"""Helpers for in-process endpoint tests."""

import tempfile;
import from jaclang.testing.testing { JacTestClient }

glob PASSWORD: str = "password123";

"""Start an isolated app instance (own database) for one test."""
def new_client() -> any {
    return JacTestClient.from_file("main.jac", base_path=tempfile.mkdtemp());
}

"""Register and log in a fresh wholesaler user."""
def new_client_as_owner() -> any {
    client = new_client();
    client.register_user("owner", PASSWORD);
    return client;
}

"""POST to a function endpoint and return its unwrapped result."""
def call(client: any, name: str, body: dict[str, any]) -> any {
    payload = client.post(f"/function/{name}", json=body).json();
    assert payload["ok"], f"{name} failed: {payload['error']}";
    return payload["data"]["result"];
}
