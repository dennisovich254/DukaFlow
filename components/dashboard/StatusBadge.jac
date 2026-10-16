import from ..ui.badge { Badge }

glob STATUS_LABELS: dict[str, str] = {
    "DRAFT": "Draft",
    "QUOTED": "Quoted",
    "PENDING_APPROVAL": "Pending approval",
    "APPROVED": "Approved",
    "PACKED": "Packed",
    "DISPATCHED": "Dispatched",
    "DELIVERED": "Delivered",
    "REJECTED": "Rejected",
    "CANCELLED": "Cancelled",
    "EXPIRED": "Expired"
};

glob STATUS_CLASSES: dict[str, str] = {
    "PENDING_APPROVAL": "bg-amber-100 text-amber-900",
    "APPROVED": "bg-[#d9f99d] text-[#1a2e05]",
    "PACKED": "bg-[#d9f99d] text-[#1a2e05]",
    "DISPATCHED": "bg-[#0e0f0c] text-white",
    "DELIVERED": "bg-[#2b2d26] text-[#d9f99d]",
    "REJECTED": "bg-orange-100 text-orange-900",
    "CANCELLED": "bg-[#f3f5ee] text-[#585c52] line-through",
    "EXPIRED": "bg-[#f3f5ee] text-[#585c52]"
};

"""Order status as text plus colour (never colour alone)."""
def:pub StatusBadge(status: str) -> JsxElement {
    <Badge variant="outline" className={"rounded-full border-transparent " + STATUS_CLASSES.get(status, "bg-[#f3f5ee] text-[#0e0f0c]")}>
        {STATUS_LABELS.get(status, status)}
    </Badge>
}
