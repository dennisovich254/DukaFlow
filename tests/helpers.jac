"""Shared test helpers."""

import from domain.errors { DomainError }

"""Return the domain error code of a caught exception (use `e.value` from testraises)."""
def code_of(exc: any) -> str {
    return (exc as DomainError).code;
}
