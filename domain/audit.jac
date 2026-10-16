"""Audit trail: order status changes, stock adjustments and price changes."""

import from domain.models { Business, AuditEvent, HasAudit }
import from domain.clock { now_iso }

def record_audit_event(
    biz: Business, actor: str, operation: str, entity: str,
    before: str, after: str, detail: str = ""
) -> AuditEvent {
    event = AuditEvent(
        actor=actor, operation=operation, entity=entity,
        before=before, after=after, detail=detail, created_at=now_iso()
    );
    biz +>:HasAudit():+> event;
    return event;
}

def list_audit_events(biz: Business) -> list[AuditEvent] {
    return [biz ->:HasAudit:->];
}
