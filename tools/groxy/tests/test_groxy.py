#!/usr/bin/env python3
"""Tests against shipped groxy modules (synthetic ids only — no real operator PII)."""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))

from tools.groxy.dispatch import process_event, run_once  # noqa: E402
from tools.groxy.dm_io import DryRunDmIO  # noqa: E402
from tools.groxy.package import build_outbound_package, build_summary_text  # noqa: E402
from tools.groxy.parse import parse_dm_event, parse_dm_text  # noqa: E402
from tools.groxy.policy import Policy, load_policy, load_policy_file  # noqa: E402
from tools.groxy.state import GroxyState  # noqa: E402

# Synthetic fixtures — never use real X account ids in tests.
OP_ID = "100001"
OP_USER = "operator_test"
STRANGER_ID = "999999999"
EXAMPLE_PR = "https://github.com/example/arch-machine/pull/31"


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
        self.assertIsNone(parse_dm_text("groxy OK: `ping`\nhost=box"))
        self.assertIsNone(parse_dm_text("✓ Done: ping\n• Reachable — ready for next command"))


class PolicyTests(unittest.TestCase):
    def test_allowlist_id(self):
        p = Policy(allowlist_ids=frozenset({OP_ID}), allowlist_usernames=frozenset())
        self.assertTrue(p.is_allowed_sender(OP_ID, None))
        self.assertFalse(p.is_allowed_sender("1", None))

    def test_high_blast(self):
        p = Policy(allowlist_ids=frozenset({"1"}))
        self.assertTrue(p.is_high_blast("pkg"))
        self.assertTrue(p.is_high_blast("rm -rf /"))
        self.assertFalse(p.is_high_blast("status"))

    def test_committed_allowlist_has_no_operator_ids(self):
        path = ROOT / "config" / "groxy" / "allowlist.conf"
        self.assertTrue(path.is_file())
        text = path.read_text(encoding="utf-8")
        # Data hygiene: committed file must not embed real operator identity.
        self.assertNotRegex(text, r"allowlist_ids=\d{5,}")
        pol = load_policy_file(path)
        self.assertEqual(len(pol.allowlist_ids), 0)

    def test_load_policy_local_file(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            conf = root / "config" / "groxy"
            conf.mkdir(parents=True)
            (conf / "allowlist.local.conf").write_text(
                f"allowlist_ids={OP_ID}\nallowlist_usernames={OP_USER}\n",
                encoding="utf-8",
            )
            pol = load_policy(repo_root=root)
            self.assertIn(OP_ID, pol.allowlist_ids)
            self.assertIn(OP_USER, pol.allowlist_usernames)


class PackageTests(unittest.TestCase):
    def test_summary_and_visual(self):
        with tempfile.TemporaryDirectory() as td:
            out = Path(td)
            inv = (
                "tinfoil inventory (tinfoil.inventory.v1)\n"
                "host: example-host  time: 2026-07-20T17:51:22+05:30\n"
                "summary: explicit=236 tools_yaml_ok=18 tools_yaml_miss=0 upgradable=0 mise=13\n"
                "ownership: arch-machine=14 omarchy=157 user=65\n"
                "=== Explicit packages (pacman -Qe) — first 40 ===\n"
                "pkg-a  1.0\n"
            )
            pkg = build_outbound_package(
                verb="status",
                ok=True,
                result_text=inv,
                host="testhost",
                cwd="/tmp/x",
                out_dir=out,
                pr_url=EXAMPLE_PR,
            )
            self.assertIn("Done: status", pkg.summary)
            self.assertIn("236 explicit", pkg.summary)
            self.assertIn(f"PR: {EXAMPLE_PR}", pkg.summary)
            self.assertNotIn("host=", pkg.summary.lower())
            self.assertNotIn("example-host", pkg.summary)
            self.assertNotIn("cwd", pkg.summary.lower())
            self.assertNotIn("pkg-a", pkg.summary)
            self.assertIn("╔", pkg.visual_text)
            self.assertNotIn("host:", pkg.visual_text.lower())
            self.assertIsNotNone(pkg.visual_path)
            assert pkg.visual_path is not None
            self.assertTrue(pkg.visual_path.is_file())
            dm = pkg.dm_text()
            self.assertIn("Done: status", dm)
            self.assertIn("PR:", dm)
            self.assertNotIn("/tmp/x", dm)

    def test_extract_pr_from_result(self):
        text = build_summary_text(
            verb="run",
            ok=True,
            result_text=f"Opened {EXAMPLE_PR.replace('/31', '/29')} for review",
            pr_url=None,
        )
        self.assertIn("pull/29", text)
        self.assertIn("✓ Done: run", text)


class InboundDispatchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="groxy-test-")
        self.effect = Path(self.tmp) / "effects"
        self.packages = Path(self.tmp) / "outbound"
        self.effect.mkdir()
        self.packages.mkdir()
        self.policy = Policy(
            allowlist_ids=frozenset({OP_ID}),
            allowlist_usernames=frozenset({OP_USER}),
            require_confirm_high_blast=True,
        )
        self.state = GroxyState()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_reject_untrusted(self):
        event = {
            "id": "e-untrusted",
            "event_type": "MessageCreate",
            "sender_id": STRANGER_ID,
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
            "sender_id": OP_ID,
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
            "sender_id": OP_ID,
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
            reply_to=OP_USER,
            dry_run=True,
        )
        self.assertTrue(r.accepted)
        self.assertIsNotNone(r.host)
        assert r.host is not None
        self.assertTrue(r.host.ok)
        self.assertIsNotNone(r.host.effect_path)
        assert r.host.effect_path is not None
        effect = r.host.effect_path.read_text(encoding="utf-8")
        self.assertIn("Reachable", effect)
        self.assertIsNotNone(r.package)
        assert r.package is not None
        dm = r.package.dm_text()
        self.assertIn("Done: ping", dm)
        self.assertNotIn("host=", dm.lower())
        self.assertNotIn("cwd", dm.lower())
        self.assertTrue(r.package.visual_text.strip())
        self.assertTrue(r.send_result and r.send_result.get("ok"))
        sends = list((self.packages / "sends").glob("send-*.txt"))
        self.assertTrue(sends)
        body = sends[0].read_text(encoding="utf-8")
        self.assertIn("Done: ping", body)

    def test_high_blast_requires_confirm(self):
        event = {
            "id": "e-pkg",
            "sender_id": OP_ID,
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
        # Allow the fixture operator id
        policy = Policy(
            allowlist_ids=frozenset({OP_ID}),
            allowlist_usernames=frozenset(),
            require_confirm_high_blast=True,
        )
        report = run_once(
            reader,
            policy=policy,
            state=self.state,
            effect_dir=self.effect,
            package_dir=self.packages,
            sender=reader,
            reply_to=OP_USER,
            dry_run=True,
        )
        reasons = [p.reason for p in report.processed]
        self.assertTrue(
            any(r in ("ok", "host_failed") for r in reasons),
            f"expected host status processing, got {reasons}",
        )
        has_visual = False
        for p in report.processed:
            if p.package and p.package.visual_text:
                has_visual = True
                self.assertTrue(
                    "Done:" in (p.package.summary or "") or "Failed:" in (p.package.summary or "")
                )
                self.assertNotIn("host=", (p.package.summary or "").lower())
        self.assertTrue(has_visual, "outbound summary/visual missing")


class EntryExistsTests(unittest.TestCase):
    def test_bin_groxy_exists(self):
        path = ROOT / "bin" / "groxy"
        self.assertTrue(path.is_file())
        text = path.read_text(encoding="utf-8")
        self.assertIn("tools.groxy", text)


if __name__ == "__main__":
    unittest.main()
