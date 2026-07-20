"""Build outbound summary + visual packages for XChat (outcome-first, no system noise)."""

from __future__ import annotations

import json
import os
import re
import subprocess
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# URLs we surface in DMs
_PR_URL_RE = re.compile(
    r"https?://(?:www\.)?github\.com/[\w.-]+/[\w.-]+/pull/\d+",
    re.IGNORECASE,
)
_ISSUE_URL_RE = re.compile(
    r"https?://(?:www\.)?github\.com/[\w.-]+/[\w.-]+/issues/\d+",
    re.IGNORECASE,
)

# Lines that look like system/debug noise — never put in the DM body
_NOISE_LINE_RE = re.compile(
    r"(?i)^("
    r"host[=:]|"
    r"cwd[=:]|"
    r"utc[=:]|"
    r"user[=:]|"
    r"root[=:]|"
    r"path[=:]|"
    r"effect_path|"
    r"exit_code|"
    r"duration|"
    r"tinfoil inventory|"
    r"=== Explicit packages|"
    r"\[media\]|"
    r"Media uploaded|"
    r"pong from |"
    r"PYTHON|"
    r"home/|"
    r"/usr/|"
    r"mzapan|"
    r")"
)


@dataclass
class OutboundPackage:
    """One outbound package destined for XChat DM (live or dry-run)."""

    summary: str
    visual_text: str
    visual_path: Path | None
    media_path: Path | None
    metadata: dict[str, Any] = field(default_factory=dict)

    def dm_text(self, max_chars: int = 900) -> str:
        """Chat body: done bullets + PR link + compact visual (no system fields)."""
        parts = [self.summary.strip()]
        if self.visual_text.strip():
            parts.append(self.visual_text.strip())
        body = "\n\n".join(parts)
        if len(body) <= max_chars:
            return body
        return body[: max_chars - 12] + "\n…(more)"

    def write_files(self, out_dir: Path) -> dict[str, Path]:
        """Write dry-run / archive files; returns path map."""
        out_dir.mkdir(parents=True, exist_ok=True)
        summary_path = out_dir / "summary.txt"
        visual_path = out_dir / "visual.txt"
        meta_path = out_dir / "package.json"
        dm_path = out_dir / "dm_payload.txt"
        summary_path.write_text(self.summary, encoding="utf-8")
        visual_path.write_text(self.visual_text, encoding="utf-8")
        dm_path.write_text(self.dm_text(), encoding="utf-8")
        meta = {
            "summary_file": str(summary_path),
            "visual_file": str(visual_path),
            "dm_payload_file": str(dm_path),
            "media_path": str(self.media_path) if self.media_path else None,
            "visual_image": str(self.visual_path) if self.visual_path else None,
            "metadata": self.metadata,
        }
        meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
        written = {
            "summary": summary_path,
            "visual": visual_path,
            "dm_payload": dm_path,
            "package_json": meta_path,
        }
        if self.visual_path and self.visual_path.is_file():
            dest = out_dir / self.visual_path.name
            if self.visual_path.resolve() != dest.resolve():
                dest.write_bytes(self.visual_path.read_bytes())
            written["visual_image"] = dest
        return written


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def extract_links(text: str) -> list[str]:
    """PR links first, then issues; de-duplicated, order preserved."""
    found: list[str] = []
    for rx in (_PR_URL_RE, _ISSUE_URL_RE):
        for m in rx.finditer(text or ""):
            url = m.group(0).rstrip(").,;")
            if url not in found:
                found.append(url)
    return found


def detect_pr_link(repo_dir: Path | None = None) -> str | None:
    """
    Best-effort PR URL for the current branch:
    1) GROXY_PR_URL env
    2) gh pr view --json url
    3) None
    """
    env = (os.environ.get("GROXY_PR_URL") or "").strip()
    if env:
        return env
    cwd = str(repo_dir) if repo_dir else None
    try:
        proc = subprocess.run(
            ["gh", "pr", "view", "--json", "url", "-q", ".url"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=12,
            check=False,
        )
        url = (proc.stdout or "").strip()
        if proc.returncode == 0 and url.startswith("http"):
            return url
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass
    return None


def _inventory_done_lines(raw: str) -> list[str]:
    """Turn inventory.sh text into 2–4 outcome bullets (no package dump)."""
    lines: list[str] = []
    # summary: explicit=236 tools_yaml_ok=18 …
    m = re.search(
        r"summary:\s*explicit=(\d+)\s+tools_yaml_ok=(\d+)\s+tools_yaml_miss=(\d+)\s+upgradable=(\d+)\s+mise=(\d+)",
        raw,
    )
    if m:
        lines.append(f"Inventory: {m.group(1)} explicit packages")
        lines.append(f"tools.yaml ok={m.group(2)} miss={m.group(3)}; upgradable={m.group(4)}")
    om = re.search(r"ownership:\s*arch-machine=(\d+)\s+omarchy=(\d+)\s+user=(\d+)", raw)
    if om:
        lines.append(f"Ownership: arch-machine {om.group(1)} · omarchy {om.group(2)} · user {om.group(3)}")
    if not lines and "inventory" in raw.lower():
        lines.append("Inventory snapshot finished")
    return lines


def distill_done_lines(verb: str, ok: bool, result_text: str) -> list[str]:
    """
    Convert raw host output into short 'what got done' bullets.
    Strips system paths/hosts; prefers structured inventory stats and PR-ish outcomes.
    """
    raw = (result_text or "").strip()
    verb = (verb or "task").lower()
    done: list[str] = []

    if verb in ("status", "inventory"):
        done = _inventory_done_lines(raw)
        if not done:
            done = ["Inventory finished" if ok else "Inventory failed"]
        return done

    if verb == "ping":
        return ["Reachable — ready for next command"] if ok else ["Unreachable"]

    if verb == "help":
        return ["Command list ready (help / status / inventory / audit / run …)"]

    if verb == "audit":
        # Prefer first non-noise, non-usage lines
        useful = [
            ln.strip()
            for ln in raw.splitlines()
            if ln.strip() and not _NOISE_LINE_RE.match(ln.strip()) and not ln.strip().startswith("Usage")
        ][:3]
        if useful:
            return [f"Audit: {useful[0][:80]}"] + [u[:80] for u in useful[1:3]]
        return ["Security audit finished" if ok else "Security audit failed"]

    if verb == "omarchy":
        useful = [
            ln.strip()
            for ln in raw.splitlines()
            if ln.strip() and not _NOISE_LINE_RE.match(ln.strip())
        ][:4]
        return useful or (["Omarchy status finished"] if ok else ["Omarchy status failed"])

    if verb == "run":
        # Prefer markdown-ish conclusions / short non-noise lines
        candidates: list[str] = []
        for ln in raw.splitlines():
            s = ln.strip()
            if not s or _NOISE_LINE_RE.match(s):
                continue
            if s.startswith("```") or s.startswith("|---"):
                continue
            # Drop tool chatter
            if s.startswith("Running ") or s.startswith("I'll ") or s.startswith("I will "):
                continue
            candidates.append(s[:120])
            if len(candidates) >= 5:
                break
        if candidates:
            return candidates[:4]
        return ["Grok task finished" if ok else "Grok task failed"]

    if verb in ("pkg", "actuate", "install", "expand", "remediate", "apply"):
        if "held" in raw.lower() or "confirm" in raw.lower():
            return [raw.splitlines()[0][:120]] if raw else ["Needs confirm"]
        useful = [ln.strip() for ln in raw.splitlines() if ln.strip() and not _NOISE_LINE_RE.match(ln.strip())][:4]
        return useful or ([f"`{verb}` finished"] if ok else [f"`{verb}` failed"])

    # Generic: first clean lines
    for ln in raw.splitlines():
        s = ln.strip()
        if not s or _NOISE_LINE_RE.match(s):
            continue
        if len(s) > 140:
            s = s[:137] + "…"
        done.append(s)
        if len(done) >= 4:
            break
    if not done:
        done = [f"`{verb}` done" if ok else f"`{verb}` failed"]
    return done


def build_summary_text(
    *,
    verb: str,
    ok: bool,
    result_text: str,
    pr_url: str | None = None,
    extra_links: list[str] | None = None,
) -> str:
    """
    Operator-facing summary:
      ✓ Done: <verb>
      • bullet
      PR: <url>
    No host/cwd/utc.
    """
    mark = "✓" if ok else "✗"
    title = f"{mark} Done: {verb}" if ok else f"{mark} Failed: {verb}"
    bullets = distill_done_lines(verb, ok, result_text)
    lines = [title]
    for b in bullets:
        if b.startswith("•") or b.startswith("-"):
            lines.append(b if b.startswith("•") else "• " + b.lstrip("- ").strip())
        else:
            lines.append(f"• {b}")

    links: list[str] = []
    if pr_url:
        links.append(pr_url)
    for u in extract_links(result_text or ""):
        if u not in links:
            links.append(u)
    if extra_links:
        for u in extra_links:
            if u and u not in links:
                links.append(u)
    for u in links[:3]:
        if "/pull/" in u:
            lines.append(f"PR: {u}")
        elif "/issues/" in u:
            lines.append(f"Issue: {u}")
        else:
            lines.append(u)
    return "\n".join(lines)


def build_visual_panel(
    *,
    verb: str,
    ok: bool,
    done_lines: list[str] | None = None,
    pr_url: str | None = None,
) -> str:
    """Compact visual board: status + done lines + optional PR (no host/cwd)."""
    status = "OK" if ok else "FAIL"
    bar = "═" * 32
    body = done_lines or []
    inner_rows: list[str] = []
    for ln in body[:5]:
        clip = ln[:36]
        inner_rows.append(f"│ {clip:<36} │")
    if pr_url:
        # short PR display: .../pull/N
        short = pr_url
        m = re.search(r"(pull/\d+)$", pr_url)
        if m:
            short = m.group(1)
        inner_rows.append(f"│ PR {short[:33]:<33} │")
    if not inner_rows:
        inner_rows = [f"│ {'(no outcomes)':<36} │"]
    return "\n".join(
        [
            f"╔{bar}╗",
            f"║ {status:<4}  {verb[:20]:<20}          ║",
            f"╠{bar}╣",
            *inner_rows,
            f"╚{bar}╝",
        ]
    )


def render_visual_png(
    out_path: Path,
    *,
    title: str,
    status: str,
    detail_lines: list[str],
    pr_url: str | None = None,
) -> Path:
    """Small PNG: status + done lines + optional PR (no host/cwd)."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image, ImageDraw, ImageFont  # type: ignore

        w, h = 640, 360
        img = Image.new("RGB", (w, h), (18, 22, 28))
        draw = ImageDraw.Draw(img)
        draw.rectangle([8, 8, w - 9, h - 9], outline=(80, 200, 140), width=3)
        draw.rectangle([20, 20, w - 21, 72], fill=(30, 48, 40))
        try:
            font = ImageFont.load_default()
        except Exception:
            font = None
        color_ok = (120, 220, 160) if status.upper() == "OK" else (240, 120, 100)
        draw.text((32, 32), f"{status.upper()}  ·  {title[:48]}", fill=color_ok, font=font)
        y = 96
        for ln in detail_lines[:8]:
            draw.text((36, y), ln[:72], fill=(210, 220, 230), font=font)
            y += 24
        if pr_url:
            draw.text((36, y + 8), f"PR: {pr_url[:70]}", fill=(140, 190, 255), font=font)
        img.save(out_path, format="PNG")
        return out_path
    except Exception:
        return _write_minimal_diagram_png(out_path, title=title, status=status)


def _write_minimal_diagram_png(out_path: Path, *, title: str, status: str) -> Path:
    """Write a simple multi-color PNG without Pillow (stdlib zlib)."""
    import struct
    import zlib

    width, height = 320, 160
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            if 10 <= x < width - 10 and 10 <= y < height - 10:
                if y < 40:
                    r, g, b = (40, 90, 60) if status.upper() == "OK" else (90, 40, 40)
                elif 100 <= y < 140 and ((20 <= x < 100) or (120 <= x < 200) or (220 <= x < 300)):
                    r, g, b = (50, 80, 120)
                else:
                    r, g, b = (18, 22, 28)
            else:
                r, g, b = (80, 200, 140)
            row.extend([r, g, b])
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    out_path.write_bytes(png)
    out_path.with_suffix(".png.txt").write_text(
        f"groxy visual ({status}): {title}\n", encoding="utf-8"
    )
    return out_path


def build_outbound_package(
    *,
    verb: str,
    ok: bool,
    result_text: str,
    host: str = "localhost",  # retained for callers; never put in DM body
    cwd: str = ".",
    out_dir: Path | None = None,
    extra_meta: dict[str, Any] | None = None,
    pr_url: str | None = None,
) -> OutboundPackage:
    """Compose outcome-first summary + visual for a command result."""
    status = "OK" if ok else "FAIL"
    # Resolve PR if not provided
    if pr_url is None:
        root = None
        try:
            from .host import repo_root

            root = repo_root()
        except Exception:
            root = Path(cwd) if cwd and cwd != "." else None
        pr_url = detect_pr_link(root)

    done = distill_done_lines(verb, ok, result_text)
    summary = build_summary_text(
        verb=verb,
        ok=ok,
        result_text=result_text,
        pr_url=pr_url,
    )
    visual_text = build_visual_panel(
        verb=verb,
        ok=ok,
        done_lines=done,
        pr_url=pr_url,
    )
    visual_img: Path | None = None
    media: Path | None = None
    if out_dir is not None:
        out_dir.mkdir(parents=True, exist_ok=True)
        visual_img = render_visual_png(
            out_dir / "visual.png",
            title=verb,
            status=status,
            detail_lines=done,
            pr_url=pr_url,
        )
        media = visual_img

    meta = {
        "verb": verb,
        "ok": ok,
        "built_at": _now_iso(),
        "pr_url": pr_url,
        "done_lines": done,
        "has_visual_text": True,
        "has_visual_image": visual_img is not None,
        # keep host/cwd only in metadata for debugging archives — not in DM
        "host_meta": host,
        "cwd_meta": cwd,
    }
    if extra_meta:
        meta.update(extra_meta)
    return OutboundPackage(
        summary=summary,
        visual_text=visual_text,
        visual_path=visual_img,
        media_path=media,
        metadata=meta,
    )


def package_to_dict(pkg: OutboundPackage) -> dict[str, Any]:
    d = asdict(pkg)
    d["visual_path"] = str(pkg.visual_path) if pkg.visual_path else None
    d["media_path"] = str(pkg.media_path) if pkg.media_path else None
    d["dm_text"] = pkg.dm_text()
    return d
