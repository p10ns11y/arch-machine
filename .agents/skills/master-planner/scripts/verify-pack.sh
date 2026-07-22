#!/usr/bin/env bash
# Verify skill pack wiring (lock + relative links + overlays).
set -euo pipefail

PROJECT="${1:-.}"
cd "$PROJECT"
fail=0

echo "== skills-lock =="
if [[ -f skills-lock.json ]]; then
  echo "OK   skills-lock.json"
else
  echo "FAIL missing skills-lock.json"
  fail=$((fail + 1))
fi

echo "== .agents/skills =="
for need in ai-optimization fusion-sage higher-order-decision-architect \
  stellar-roadmap verification-cockpit agent-orchestrator looper git-worktrees \
  eagle-satellite-elomaxz session-unit-order master-planner; do
  if [[ -f ".agents/skills/$need/SKILL.md" ]]; then
    echo "OK   $need"
  else
    echo "FAIL missing .agents/skills/$need/SKILL.md"
    fail=$((fail + 1))
  fi
done

echo "== relative agent links =="
for agent in .cursor .grok; do
  [[ -d "$agent/skills" ]] || { echo "FAIL missing $agent/skills"; fail=$((fail + 1)); continue; }
  while IFS= read -r -d '' link; do
    name="$(basename "$link")"
    target="$(readlink "$link")"
    case "$target" in
      ../../.agents/skills/*) echo "OK   $agent/skills/$name → $target" ;;
      /*)
        echo "FAIL absolute symlink $agent/skills/$name → $target"
        fail=$((fail + 1))
        ;;
      *)
        if [[ -f "$link/SKILL.md" ]]; then
          echo "OK   $agent/skills/$name resolves"
        else
          echo "FAIL broken $agent/skills/$name → $target"
          fail=$((fail + 1))
        fi
        ;;
    esac
  done < <(find "$agent/skills" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
done

echo "== overlays =="
if [[ -d .agents/overlays ]]; then
  for f in .agents/overlays/*.md; do
    [[ -f "$f" ]] || continue
    lines="$(wc -l <"$f" | tr -d ' ')"
    if [[ "$lines" -gt 80 ]]; then
      echo "WARN fat overlay ($lines): $f"
    else
      echo "OK   $(basename "$f") ($lines lines)"
    fi
  done
else
  echo "WARN no .agents/overlays"
fi

echo "---"
if [[ "$fail" -eq 0 ]]; then
  echo "verify-pack: PASS"
else
  echo "verify-pack: FAIL ($fail)"
  exit 1
fi
