import from ...lib.money { format_kes }

glob DONUT_COLOURS: list[str] = ["#0e0f0c", "#65a30d", "#a3e635", "#d9f99d", "#9ca38f"];

"""Column chart drawn with flex boxes. Each column is a button: hover, focus or tap shows its value."""
def:pub BarChart(labels: list[str], values: list[int], money: bool = True) -> JsxElement {
    has active: int = -1;
    top = max(values) if len(values) > 0 else 0;
    shown = active if active >= 0 else len(values) - 1;

    def set_active(i: int) {
        active = i;
    }

    def readout(i: int) -> str {
        if i < 0 or i >= len(values) { return ""; }
        return (format_kes(values[i]) if money else str(values[i])) + " · " + labels[i];
    }

    <div>
        <p className="mb-3 text-sm font-medium tabular-nums" aria-live="polite">{readout(shown)}</p>
        <div className="flex h-44 items-end gap-2" role="group" aria-label="Daily values">
            {for (i, v) in enumerate(values) {
                <button key={str(i)} type="button"
                    onMouseEnter={lambda (e: any) { set_active(i); }}
                    onMouseLeave={lambda (e: any) { set_active(-1); }}
                    onFocus={lambda (e: any) { set_active(i); }}
                    onBlur={lambda (e: any) { set_active(-1); }}
                    aria-label={readout(i)}
                    className="group flex h-full flex-1 cursor-pointer flex-col justify-end outline-none">
                    <div className={"w-full rounded-t-lg transition-all group-focus-visible:ring-2 group-focus-visible:ring-[#0e0f0c] " + ("bg-[#0e0f0c]" if i == shown else "bg-[#a3e635] group-hover:bg-[#65a30d]")}
                        style={{"height": str(max(int(v * 100 / top) if top > 0 else 0, 3)) + "%"}}></div>
                </button>
            }}
        </div>
        <div className="mt-2 flex gap-2">
            {for (i, l) in enumerate(labels) {
                <span key={str(i)} className="flex-1 text-center text-[11px] text-muted-foreground">{l}</span>
            }}
        </div>
    </div>
}

"""Ranked horizontal bars: name, value, and a proportional track."""
def:pub HBarList(names: list[str], values: list[int], captions: list[str]) -> JsxElement {
    top = max(values) if len(values) > 0 else 0;
    <ul className="flex flex-col gap-4">
        {for (i, n) in enumerate(names) {
            <li key={str(i)}>
                <div className="flex items-baseline justify-between gap-3 text-sm">
                    <span className="truncate font-medium">{n}</span>
                    <span className="shrink-0 tabular-nums text-muted-foreground">{captions[i]}</span>
                </div>
                <div className="mt-1.5 h-2 w-full rounded-full bg-[#f3f5ee]">
                    <div className="h-2 rounded-full bg-[#65a30d]"
                        style={{"width": str(max(int(values[i] * 100 / top) if top > 0 else 0, 3)) + "%"}}></div>
                </div>
            </li>
        }}
    </ul>
}

"""Donut with a legend. Slices are listed as text too, so colour is never the only cue."""
def:pub Donut(names: list[str], values: list[int], centre: str = "") -> JsxElement {
    total = sum(values);
    stops: list[str] = [];
    acc = 0;
    for (i, v) in enumerate(values) {
        start = int(acc * 360 / total) if total > 0 else 0;
        acc += v;
        end = int(acc * 360 / total) if total > 0 else 0;
        stops.append(DONUT_COLOURS[i % len(DONUT_COLOURS)] + " " + str(start) + "deg " + str(end) + "deg");
    }
    paint = "conic-gradient(" + ", ".join(stops) + ")" if total > 0 else "conic-gradient(#f3f5ee 0deg 360deg)";
    <div className="flex flex-wrap items-center gap-6">
        <div className="relative size-32 shrink-0 rounded-full" style={{"background": paint}} role="img"
            aria-label={"Share by " + ", ".join([names[i] + " " + str(values[i]) for i in range(len(names))])}>
            <div className="absolute inset-4 flex flex-col items-center justify-center rounded-full bg-white">
                <span className="display text-xl font-medium">{str(total)}</span>
                <span className="text-[11px] text-muted-foreground">{centre}</span>
            </div>
        </div>
        <ul className="flex flex-col gap-2 text-sm">
            {for (i, n) in enumerate(names) {
                <li key={str(i)} className="flex items-center gap-2">
                    <span className="size-3 rounded-full" style={{"background": DONUT_COLOURS[i % len(DONUT_COLOURS)]}}></span>
                    <span>{n}</span>
                    <span className="tabular-nums text-muted-foreground">{values[i]} ({int(values[i] * 100 / total) if total > 0 else 0}%)</span>
                </li>
            }}
        </ul>
    </div>
}
