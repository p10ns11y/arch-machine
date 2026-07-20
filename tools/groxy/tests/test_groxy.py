#!/usr/bin/env python3
"""Tests against shipped groxy modules (real parse/policy/dispatch/package paths)."""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

# Repo root on path
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.groxy.dispatch import process_event, run_once  # noqa: E402
from tools.groxy.dm_io import DryRunDmIO  # noqa: E402
from tools.groxy.package import build_outbound_package  # noqa: E402
from tools.groxy.parse import parse_dm_event, parse_dm_text  # noqa: E402
from tools.groxy.policy import Policy, load_policy_file  # noqa: E402
from tools.groxy.state import GroxyState  # noqa: E402


class ParseTests(unittest.TestCase):
    def test_prefix_status(self):
        cmd = parse_dm_text("!g status")
        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertEqual(cmd.verb, "status")

    def test_inventory_alias(self):
        cmd = parse_dm_text("groxy inv")
        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertEqual(cmd.verb, "inventory")

    def test_confirm_token(self):
        cmd = parse_dm_text("confirm deadbeef pkg install foo")
        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertEqual(cmd.confirm_token, "deadbeef")
        self.assertEqual(cmd.verb, "pkg")

    def test_event_parse(self):
        cmd = parse_dm_event(
            {
                "id": "1",
                "event_type": "MessageCreate",
                "text": "ping",
                "sender_id": "1",
            }
        )
        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertEqual(cmd.verb, "ping")

    def test_free_chat_not_command(self):
        self.assertIsNone(parse_dm_text("I have lost MFA for Grok not for X"))
        self.assertIsNone(parse_dm_text("No the form only mentions X"))

    def test_prefixed_freeform_is_run(self):
        cmd = parse_dm_text("!g how much disk free")
        self.assertIsNotNone(cmd)
        assert cmd is not None
        self.assertEqual(cmd.verb, "run")
        self.assertIn("disk", cmd.args)

    def test_outbound_noise_ignored(self):
        self.assertIsNone(parse_dm_text("groxy OK: `ping`\nhost=mzapan"))


class PolicyTests(unittest.TestCase):
    def test_allowlist_id(self):
        p = Policy(allowlist_ids=frozenset({"295441607"}), allowlist_usernames=frozenset())
        self.assertTrue(p.is_allowed_sender("295441607", None))
        self.assertFalse(p.is_allowed_sender("1", None))

    def test_high_blast(self):
        p = Policy(allowlist_ids=frozenset({"1"}))
        self.assertTrue(p.is_high_blast("pkg"))
        self.assertTrue(p.is_high_blast("rm -rf /"))
        self.assertFalse(p.is_high_blast("status"))

    def test_load_repo_allowlist(self):
        path = ROOT / "config" / "groxy" / "allowlist.conf"
        self.assertTrue(path.is_file())
        pol = load_policy_file(path)
        self.assertIn("295441607", pol.allowlist_ids)


class PackageTests(unittest.TestCase):
    def test_summary_and_visual(self):
        with tempfile.TemporaryDirectory() as td:
            out = Path(td)
            pkg = build_outbound_package(
                verb="status",
                ok=True,
                result_text="inventory lines\nok",
                host="testhost",
                cwd="/tmp/x",
                out_dir=out,
            )
            self.assertIn("groxy", pkg.summary.lower())
            self.assertIn("status", pkg.summary.lower())
            self.assertIn("╔", pkg.visual_text)  # visual panel
            self.assertIsNotNone(pkg.visual_path)
            assert pkg.visual_path is not None
            self.assertTrue(pkg.visual_path.is_file())
            self.assertGreater(pkg.visual_path.stat().st_size, 50)
            written = pkg.write_files(out / "pack")
            dm = written["dm_payload"].read_text(encoding="utf-8")
            self.assertIn("visual", dm.lower())
            self.assertIn("groxy", dm.lower())


class InboundDispatchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="groxy-test-")
        self.effect = Path(self.tmp) / "effects"
        self.packages = Path(self.tmp) / "outbound"
        self.effect.mkdir()
        self.packages.mkdir()
        self.policy = Policy(
            allowlist_ids=frozenset({"295441607"}),
            allowlist_usernames=frozenset({"peramanathan"}),
            require_confirm_high_blast=True,
        )
        self.state = GroxyState()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_reject_untrusted(self):
        event = {
            "id": "e-untrusted",
            "event_type": "MessageCreate",
            "sender_id": "111",
            "text": "status",
        }
        r = process_event(
            event,
            policy=self.policy,
            state=self.state,
            effect_dir=self.effect,
            package_dir=self.packages,
        )
        self.assertFalse(r.accepted)
        self.assertEqual(r.reason, "sender_not_allowlisted")

    def test_reject_public_post(self):
        event = {
            "id": "e-pub",
            "sender_id": "295441607",
            "text": "status",
            "is_public_post": True,
        }
        r = process_event(
            event,
            policy=self.policy,
            state=self.state,
            effect_dir=self.effect,
            package_dir=self.packages,
        )
        self.assertFalse(r.accepted)
        self.assertEqual(r.reason, "public_post_rejected")

    def test_allowlisted_ping_produces_effect_and_package(self):
        sender = DryRunDmIO(fixture_path=None, out_dir=self.packages / "sends")
        event = {
            "id": "e-ping-1",
            "event_type": "MessageCreate",
            "sender_id": "295441607",
            "text": "!g ping",
            "dm_conversation_id": "c1",
        }
        r = process_event(
            event,
            policy=self.policy,
            state=self.state,
            effect_dir=self.effect,
            package_dir=self.packages,
            sender=sender,
            reply_to="Peramanathan",
            dry_run=True,
        )
        self.assertTrue(r.accepted)
        self.assertIsNotNone(r.host)
        assert r.host is not None
        self.assertTrue(r.host.ok)
        self.assertIsNotNone(r.host.effect_path)
        assert r.host.effect_path is not None
        self.assertTrue(r.host.effect_path.is_file())
        self.assertIn("pong", r.host.effect_path.read_text(encoding="utf-8"))
        self.assertIsNotNone(r.package)
        assert r.package is not None
        self.assertIn("visual", r.package.dm_text().lower())
        self.assertTrue(r.package.visual_text.strip())
        # dry-run send wrote a file
        self.assertTrue(r.send_result and r.send_result.get("ok"))
        sends = list((self.packages / "sends").glob("send-*.txt"))
        self.assertTrue(sends)
        body = sends[0].read_text(encoding="utf-8")
        self.assertIn("groxy", body.lower())
        self.assertIn("visual", body.lower())

    def test_high_blast_requires_confirm(self):
        event = {
            "id": "e-pkg",
            "sender_id": "295441607",
            "text": "pkg install evil",
            "event_type": "MessageCreate",
        }
        r = process_event(
            event,
            policy=self.policy,
            state=self.state,
            effect_dir=self.effect,
            package_dir=self.packages,
        )
        self.assertTrue(r.accepted)
        self.assertEqual(r.reason, "pending_confirm")
        self.assertIsNotNone(r.pending_token)

    def test_fixture_once_status(self):
        fixture = ROOT / "tools" / "groxy" / "fixtures" / "inbound_status.json"
        self.assertTrue(fixture.is_file())
        reader = DryRunDmIO(fixture_path=fixture, out_dir=self.packages / "sends")
        # Fresh state path semantics
        report = run_once(
            reader,
            policy=self.policy,
            state=self.state,
            effect_dir=self.effect,
            package_dir=self.packages,
            sender=reader,
            reply_to="Peramanathan",
            dry_run=True,
        )
        reasons = [p.reason for p in report.processed]
        # Expect allowlisted status accepted; evil rejected; public rejected
        self.assertTrue(
            any(r in ("ok", "host_failed") for r in reasons),
            f"expected host status processing, got {reasons}",
        )
        self.assertTrue(
            any(p.reason == "sender_not_allowlisted" for p in report.processed)
            or report.rejected >= 1
            or any(p.reason == "sender_not_allowlisted" for p in report.processed)
        )
        # Host effect for status/inventory should exist if inventory.sh ran or failed with log
        effects = list(self.effect.glob("host-effect-*.txt"))
        # status writes inventory effect
        self.assertTrue(
            effects or any(p.host and p.host.effect_path for p in report.processed),
            "expected host-side effect from allowlisted status",
        )
        # Outbound package with summary+visual
        packs = list(self.packages.glob("evt-*/dm_payload.txt")) + list(
            self.packages.glob("evt-*/summary.txt")
        )
        # process_event write_files for successful host path
        has_visual = False
        for p in report.processed:
            if p.package and p.package.visual_text:
                has_visual = True
                self.assertIn("groxy", (p.package.summary or "").lower())
                self.assertTrue(p.package.visual_text)
        self.assertTrue(has_visual or packs, "outbound summary/visual missing")


class EntryExistsTests(unittest.TestCase):
    def test_bin_groxy_exists(self):
        path = ROOT / "bin" / "groxy"
        self.assertTrue(path.is_file())
        text = path.read_text(encoding="utf-8")
        self.assertIn("tools.groxy", text)


if __name__ == "__main__":
    unittest.main()
