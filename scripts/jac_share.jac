"""Jac share report: counts lines per language over the files git tracks.

Run from the repo root: `jac run --no-serve scripts/jac_share.jac`.
"Code" means source in any programming or styling language; markdown, YAML, TOML, JSON and
lock files are documentation and configuration, reported separately."""

import subprocess;
import from pathlib { Path }

glob CODE_LANGS: dict[str, str] = {
    ".jac": "Jac", ".css": "CSS", ".js": "JavaScript", ".jsx": "JavaScript", ".ts": "TypeScript",
    ".tsx": "TypeScript", ".py": "Python", ".html": "HTML", ".sh": "Shell"
};
glob CONFIG_EXTS: list[str] = [".md", ".yml", ".yaml", ".toml", ".json", ".lock", ".txt", ".example"];

def tracked_files() -> list[str] {
    out = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout;
    return [f for f in out.split("\n") if len(f) > 0];
}

def line_count(path: str) -> int {
    try {
        return len([ln for ln in Path(path).read_text().split("\n") if ln.strip() != ""]);
    } except Exception {
        return 0;
    }
}

def pct(part: int, whole: int) -> str {
    return str(round(part * 1000 / whole) / 10) + "%" if whole > 0 else "n/a";
}

with entry {
    code: dict[str, int] = {};
    config = 0;
    for f in tracked_files() {
        ext = "." + f.split(".")[-1] if "." in f.split("/")[-1] else "";
        if ext in CODE_LANGS {
            lang = CODE_LANGS[ext];
            code[lang] = code.get(lang, 0) + line_count(f);
        } elif ext in CONFIG_EXTS {
            config += line_count(f);
        }
    }
    total = sum(code.values());
    jac = code.get("Jac", 0);
    print("Non-blank lines in tracked files, by language");
    for (lang, n) in sorted(code.items(), key=lambda (kv: tuple[str, int]) { -kv[1]; }) {
        print(f"  {lang:<12} {n:>7}  {pct(n, total)} of code");
    }
    print(f"  {'Config/docs':<12} {config:>7}  (markdown, YAML, TOML, JSON, lock files)");
    print(f"Jac share of code: {pct(jac, total)}");
    print(f"Jac share including config and docs as non-Jac: {pct(jac, total + config)}");
}
