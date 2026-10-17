"""Where the compliance radar reads from: the reviewed snapshot (default) and, best effort,
a small whitelist of official sites.

Fetched text is data, never instructions. Only https URLs on the whitelist are fetched, never
IP addresses, never a redirect off the whitelist, with a time and size limit."""

import re;
import html;
import ipaddress;
import urllib.request;
import urllib.parse;
import from domain.errors { DomainError }
import from integrations.regsnapshot { SNAPSHOT }

glob WHITELIST: list[str] = [
    "kra.go.ke", "kenyalaw.org", "new.kenyalaw.org", "parliament.go.ke", "kebs.org", "treasury.go.ke", "nema.go.ke"
];
glob MAX_BYTES: int = 2097152;
glob FETCH_TIMEOUT_S: int = 10;
glob MAX_PASTE_CHARS: int = 20000;
glob KRA_BASE: str = "https://www.kra.go.ke";
glob KRA_NOTICES: str = "https://www.kra.go.ke/news-center/public-notices";
glob MAX_NOTICE_CHARS: int = 6000;
# Title words that make a notice worth reading for a goods wholesaler (the model then decides).
glob RELEVANT_WORDS: list[str] = [
    "excise", "vat", "value added", "duty", "levy", "etims", "invoic", "stock", "sugar", "goods", "tax"
];

obj SourceDoc {
    has notice_id: str,
        title: str,
        source_name: str,
        url: str,
        published_on: str,
        text: str,
        origin: str = "SNAPSHOT",
        labels: dict[str, any] = {};
}

def is_ip(host: str) -> bool {
    try {
        ipaddress.ip_address(host);
        return True;
    } except ValueError {
        return False;
    }
}

def host_allowed(host: str) -> bool {
    h = host.lower().rstrip(".");
    if is_ip(h) { return False; }
    for w in WHITELIST {
        if h == w or h.endswith("." + w) { return True; }
    }
    return False;
}

"""True only for an https URL on the whitelist, without credentials or an IP address."""
def allowed_url(url: str) -> bool {
    try {
        u = urllib.parse.urlparse(url);
    } except Exception {
        return False;
    }
    if u.scheme != "https" or not u.hostname or u.username or u.password { return False; }
    return host_allowed(u.hostname);
}

def strip_html(raw: str) -> str {
    no_blocks = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", raw);
    text = html.unescape(re.sub(r"(?s)<[^>]+>", " ", no_blocks));
    return re.sub(r"\s+", " ", text).strip();
}

obj WhitelistRedirects(urllib.request.HTTPRedirectHandler) {
    def redirect_request(req: any, fp: any, code: any, msg: any, headers: any, newurl: any) -> any {
        if not allowed_url(newurl) { raise DomainError("SOURCE_NOT_ALLOWED", "Redirect leaves the allowed sites."); }
        return urllib.request.HTTPRedirectHandler.redirect_request(self, req, fp, code, msg, headers, newurl);
    }
}

"""Fetch one whitelisted page and return its raw HTML (limits: 10 s, 2 MB)."""
def fetch_raw(url: str) -> str {
    if not allowed_url(url) {
        raise DomainError("SOURCE_NOT_ALLOWED", "Only https pages on official Kenyan sites can be fetched.");
    }
    opener = urllib.request.build_opener(WhitelistRedirects());
    req = urllib.request.Request(url, headers={"User-Agent": "DukaFlow-radar/1.0"});
    with opener.open(req, timeout=FETCH_TIMEOUT_S) as resp {
        raw = resp.read(MAX_BYTES + 1);
    }
    if len(raw) > MAX_BYTES { raise DomainError("SOURCE_TOO_LARGE", "The page is too large to read."); }
    return raw.decode("utf-8", errors="ignore");
}

"""Fetch one whitelisted page and return its text."""
def fetch_page(url: str) -> str {
    return strip_html(fetch_raw(url));
}

obj NoticeLink {
    has notice_number: str,
        url: str,
        title: str,
        published_on: str;
}

"""Notice links on the KRA public-notices page: number, absolute URL, title and date (newest first)."""
def parse_kra_list(page: str) -> list[NoticeLink] {
    out: list[NoticeLink] = [];
    seen: list[str] = [];
    for m in re.finditer(r'<a[^>]+href="([^"]*/public-notices/(\d+)-[^"]*)"[^>]*>(.*?)</a>', page, re.S) {
        href = m.group(1);
        if href in seen { continue; }
        text = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", m.group(3)))).strip();
        d = re.search(r"(\d{2})/(\d{2})/(\d{4})", text);
        if d is None { continue; }
        title = re.sub(r"^.*?\d{2}/\d{2}/\d{4}\s*", "", text).strip();
        if not title { continue; }
        seen.append(href);
        url = href if href.startswith("http") else KRA_BASE + href;
        out.append(NoticeLink(
            notice_number=m.group(2), url=url, title=title,
            published_on=d.group(3) + "-" + d.group(2) + "-" + d.group(1)
        ));
    }
    return out;
}

"""The body of a KRA notice page: the text after the share links, without the site footer."""
def kra_body(page: str) -> str {
    text = strip_html(page);
    i = text.lower().rfind("share article");
    body = text[i + len("share article"):] if i >= 0 else text;
    for stop in ["Related Articles", "Quick Links", "Subscribe", "Contact Us"] {
        j = body.find(stop);
        if j > 0 { body = body[:j]; }
    }
    return body.strip()[:MAX_NOTICE_CHARS];
}

def relevant_title(title: str) -> bool {
    t = title.lower();
    return len([w for w in RELEVANT_WORDS if w in t]) > 0;
}

"""Read the latest relevant KRA public notices live (newest first, at most `limit`), skipping
any URL in `skip_urls` (already in the reviewed snapshot) and anything older than a year."""
def fetch_kra_notices(today: str, skip_urls: list[str], limit: int = 5) -> list[SourceDoc] {
    year_ago = str(int(today[:4]) - 1) + today[4:10];
    docs: list[SourceDoc] = [];
    for link in parse_kra_list(fetch_raw(KRA_NOTICES)) {
        if len(docs) >= limit { break; }
        if link.url in skip_urls or link.published_on < year_ago or not relevant_title(link.title) { continue; }
        body = kra_body(fetch_raw(link.url));
        if len(body) < 80 { continue; }
        docs.append(SourceDoc(
            notice_id="KRA-" + link.notice_number, title=link.title,
            source_name="Kenya Revenue Authority public notice (read live)", url=link.url,
            published_on=link.published_on, text=body, origin="LIVE"
        ));
    }
    return docs;
}

"""The reviewed snapshot as documents. Labels hold the hand-checked fields used in mock mode."""
def load_snapshot() -> list[SourceDoc] {
    docs: list[SourceDoc] = [];
    for n in SNAPSHOT {
        docs.append(SourceDoc(
            notice_id=n["notice_id"], title=n["title"], source_name=n["source_name"], url=n["url"],
            published_on=n["published_on"], text=n["source_text"], origin=n["origin"], labels=n
        ));
    }
    return docs;
}

"""A notice the wholesaler pasted in (text only; capped length)."""
def pasted_doc(text: str, title: str = "") -> SourceDoc {
    body = text.strip();
    if len(body) < 40 { raise DomainError("NOTICE_TOO_SHORT", "Paste at least a couple of sentences from the notice."); }
    if len(body) > MAX_PASTE_CHARS { raise DomainError("NOTICE_TOO_LONG", "That is too long. Paste the relevant part (up to 20,000 characters)."); }
    return SourceDoc(
        notice_id="", title=title.strip() or "Pasted notice", source_name="Pasted by you", url="",
        published_on="", text=body, origin="PASTED"
    );
}
