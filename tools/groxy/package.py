"""Build outbound summary + visual explanation packages for XChat."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


@dataclass
class OutboundPackage:
    """One outbound package destined for XChat DM (live or dry-run)."""

    summary: str
    visual_text: str
    visual_path: Path | None
    media_path: Path | None
    metadata: dict[str, Any] = field(default_factory=dict)

    def dm_text(self, max_chars: int = 900) -> str:
        """Text body suitable for a single DM (summary + visual panel, truncated)."""
        body = (
            f"{self.summary.strip()}\n\n"
            f"── visual ──\n"
            f"{self.visual_text.strip()}"
        )
        if len(body) <= max_chars:
            return body
        return body[: max_chars - 20] + "\n…(truncated)"

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


def build_visual_panel(
    *,
    verb: str,
    ok: bool,
    host: str,
    cwd: str,
    lines: list[str] | None = None,
) -> str:
    """ASCII/structured visual panel for chat display."""
    status = "OK" if ok else "FAIL"
    bar = "═" * 28
    body_lines = lines or []
    inner = "\n".join(f"│ {ln[:40]:<40} │" for ln in body_lines[:8])
    if not inner:
        inner = f"│ {'(no detail lines)':<40} │"
    lines_out = [
        f"╔{bar}╗",
        f"║ groxy · {status:<6} · {verb[:12]:<12} ║",
        f"╠{bar}╣",
        *inner.splitlines(),
        f"╠{bar}╣",
        f"│ host: {host[:34]:<34} │",
        f"│ cwd:  {cwd[:34]:<34} │",
        f"│ utc:  {_now_iso():<34} │",
        f"╚{bar}╝",
    ]
    return "\n".join(lines_out)


def render_visual_png(
    out_path: Path,
    *,
    title: str,
    status: str,
    detail_lines: list[str],
) -> Path:
    """
    Render a small PNG diagram for X media upload.
    Uses Pillow when available; otherwise writes a minimal PNG via stdlib only.
    """
    out_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image, ImageDraw, ImageFont  # type: ignore

        w, h = 640, 360
        img = Image.new("RGB", (w, h), (18, 22, 28))
        draw = ImageDraw.Draw(img)
        # Frame
        draw.rectangle([8, 8, w - 9, h - 9], outline=(80, 200, 140), width=3)
        draw.rectangle([20, 20, w - 21, 72], fill=(30, 48, 40))
        try:
            font = ImageFont.load_default()
            font_lg = font
        except Exception:
            font = None
            font_lg = None
        color_ok = (120, 220, 160) if status.upper() == "OK" else (240, 120, 100)
        draw.text((32, 32), f"groxy  ·  {status.upper()}  ·  {title[:40]}", fill=color_ok, font=font_lg)
        y = 96
        for ln in detail_lines[:10]:
            draw.text((36, y), ln[:70], fill=(210, 220, 230), font=font)
            y += 22
        # Flow diagram boxes
        boxes = [
            (40, 280, 180, 330, "XChat DM"),
            (230, 280, 410, 330, "groxy"),
            (460, 280, 600, 330, "host"),
        ]
        for x0, y0, x1, y1, label in boxes:
            draw.rounded_rectangle([x0, y0, x1, y1], radius=8, outline=(100, 160, 220), width=2)
            draw.text((x0 + 18, y0 + 14), label, fill=(180, 200, 240), font=font)
        draw.line([(180, 305), (230, 305)], fill=(100, 160, 220), width=2)
        draw.line([(410, 305), (460, 305)], fill=(100, 160, 220), width=2)
        img.save(out_path, format="PNG")
        return out_path
    except Exception:
        # Fallback: 1x1 is not enough — write a tiny valid solid PNG via pure Python
        return _write_minimal_diagram_png(out_path, title=title, status=status)


def _write_minimal_diagram_png(out_path: Path, *, title: str, status: str) -> Path:
    """Write a simple multi-color PNG without Pillow (stdlib zlib)."""
    import struct
    import zlib

    width, height = 320, 160
    # RGB rows
    rows = []
    for y in range(height):
        row = bytearray([0])  # filter None
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
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(
        b"IEND", b""
    )
    # Embed title/status as a comment text chunk for debugging
    out_path.write_bytes(png)
    # Sidecar note so visual is still explained without Pillow text
    note = out_path.with_suffix(".png.txt")
    note.write_text(f"groxy visual PNG ({status}): {title}\n", encoding="utf-8")
    return out_path


def build_outbound_package(
    *,
    verb: str,
    ok: bool,
    result_text: str,
    host: str = "localhost",
    cwd: str = ".",
    out_dir: Path | None = None,
    extra_meta: dict[str, Any] | None = None,
) -> OutboundPackage:
    """Compose summary text + visual panel + PNG for a command result."""
    status = "OK" if ok else "FAIL"
    # Keep summary tight for DM
    preview = (result_text or "").strip()
    if len(preview) > 600:
        preview = preview[:600] + "\n…(truncated)"
    summary = (
        f"groxy {status}: `{verb}`\n"
        f"host={host}\n"
        f"\n{preview}"
    )
    detail = [ln for ln in preview.splitlines() if ln.strip()][:8]
    visual_text = build_visual_panel(
        verb=verb,
        ok=ok,
        host=host,
        cwd=cwd,
        lines=detail or [f"command: {verb}"],
    )
    visual_img: Path | None = None
    media: Path | None = None
    if out_dir is not None:
        out_dir.mkdir(parents=True, exist_ok=True)
        visual_img = render_visual_png(
            out_dir / "visual.png",
            title=verb,
            status=status,
            detail_lines=detail or [verb],
        )
        media = visual_img

    meta = {
        "verb": verb,
        "ok": ok,
        "host": host,
        "cwd": cwd,
        "built_at": _now_iso(),
        "has_visual_text": True,
        "has_visual_image": visual_img is not None,
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
