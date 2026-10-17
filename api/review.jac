"""Authenticated order review and agent activity endpoints."""

import from domain.models { AgentExecution }
import from domain.errors { DomainError }
import from domain.customers { find_customer }
import from domain.review { get_review_context, recent_activity }
import from api.business { current_business }
import from api.results { to_api_error }
import from api.orders { order_view }
import from api.chat { message_view }
import from api.contracts { ExecutionView, ReviewView, ReviewResult, OrderLookup }

def execution_view(customer_id: str, customer_name: str, e: AgentExecution) -> ExecutionView {
    return ExecutionView(
        message_seq=e.message_seq, customer_id=customer_id, customer_name=customer_name,
        input_type=e.input_type, outcome=e.outcome, duration_ms=e.duration_ms,
        created_at=e.created_at, steps=e.steps
    );
}

def:protect order_review(query: OrderLookup) -> ReviewResult {
    try {
        biz = current_business();
        ctx = get_review_context(biz, query.order_id);
        customer = find_customer(biz, ctx.order.customer_id);
        name = customer.name if customer else ctx.order.customer_id;
        return ReviewResult(ok=True, review=ReviewView(
            order=order_view(biz, ctx.order),
            quote_id=ctx.order.quote_id,
            quote_notes=ctx.quote_notes,
            messages=[message_view(m) for m in ctx.messages],
            executions=[execution_view(ctx.order.customer_id, name, e) for e in ctx.executions]
        ));
    } except DomainError as e {
        return ReviewResult(ok=False, error=to_api_error(e));
    }
}

def:protect recent_agent_activity() -> list[ExecutionView] {
    return [execution_view(i.customer_id, i.customer_name, i.execution) for i in recent_activity(current_business(), 50)];
}
