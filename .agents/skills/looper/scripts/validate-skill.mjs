#!/usr/bin/env node
/**
 * Structural contract test for looper skill (skills library layout).
 * Drives the real shipped SKILL.md + README index + rules/looper.mdc.
 * Exit 0 = pass; non-zero = fail with diagnostics.
 */
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const skillDir = join(__dirname, "..");
const repoRoot = join(skillDir, "..");
const skillMd = join(skillDir, "SKILL.md");
const skillReadme = join(skillDir, "README.md");
const loopCard = join(skillDir, "references", "loop-card.md");
const ruleMd = join(repoRoot, "rules", "looper.mdc");
const readmeMd = join(repoRoot, "README.md");

const failures = [];
const notes = [];

function must(cond, msg) {
  if (!cond) failures.push(msg);
  else notes.push(`ok: ${msg}`);
}

function read(p) {
  must(existsSync(p), `exists ${p}`);
  if (!existsSync(p)) return "";
  return readFileSync(p, "utf8");
}

const body = read(skillMd);
must(body.length > 0, "SKILL.md non-empty");

const fm = body.match(/^---\r?\n([\s\S]*?)\r?\n---/);
must(!!fm, "YAML frontmatter present");
const front = fm ? fm[1] : "";
const nameVal = (front.match(/^name:\s*[\"']?([^\"'\n]+)/m) || [])[1]?.trim();
must(!!nameVal && nameVal.length > 0, `frontmatter name non-empty (got ${JSON.stringify(nameVal)})`);
must(nameVal === "looper", `name is looper (got ${JSON.stringify(nameVal)})`);
must(front.includes("description:"), "frontmatter description key present");

const descLower = front.slice(front.indexOf("description:")).toLowerCase();
for (const term of ["loop", "state", "rout"]) {
  must(descLower.includes(term), `description mentions "${term}*"`);
}

const bodyLower = body.toLowerCase();
const requiredPhrases = [
  { id: "outer-state", any: ["state machine", "phase contract", "transition table"] },
  { id: "bounded-steps", any: ["max_loop_iters", "max_step_retries", "done_when"] },
  { id: "cancel", any: ["cancel", "cancelled"] },
  { id: "routing", any: ["model routing", "routing matrix"] },
  { id: "roles", all: ["fast", "coding", "review"] },
  { id: "hitl", any: ["human-in-the-loop", "hitl", "pause"] },
  { id: "review-gate", any: ["review_gate", "review gate"] },
];

for (const req of requiredPhrases) {
  if (req.all) {
    must(
      req.all.every((t) => bodyLower.includes(t)),
      `body includes roles ${req.all.join(", ")}`,
    );
  }
  if (req.any) {
    must(
      req.any.some((t) => bodyLower.includes(t)),
      `body includes one of [${req.any.join(" | ")}] (${req.id})`,
    );
  }
}

const roleHits = ["fast", "explore", "coding", "deep", "review"].filter((r) =>
  bodyLower.includes(r),
);
must(roleHits.length >= 3, `≥3 model roles present (found ${roleHits.length}: ${roleHits.join(", ")})`);

must(body.includes("agent-orchestrator"), "composes with agent-orchestrator");
must(body.includes("subagent-delegation"), "composes with subagent-delegation");
must(body.includes("fusion-sage") || body.includes("ai-optimization"), "composes with fusion/fission");

must(existsSync(loopCard), "references/loop-card.md exists");
const card = read(loopCard);
must(card.toLowerCase().includes("phase"), "loop-card mentions phase");

const skillReadmeBody = read(skillReadme);
must(skillReadmeBody.includes("SKILL.md"), "skill README points at SKILL.md");
must(
  skillReadmeBody.includes("Peramanathan") || skillReadmeBody.includes("2067890630345494578"),
  "skill README cites X thesis post",
);

const rule = read(ruleMd);
must(rule.includes("---"), "looper.mdc has frontmatter");
must(/alwaysApply:\s*false/i.test(rule), "rule alwaysApply false");
must(rule.includes("looper"), "rule points at looper skill");

const readme = read(readmeMd);
must(readme.includes("looper"), "README.md indexes looper");
must(
  /loop|multi-model|structured agent|state machine/i.test(readme),
  "README routes loop/routing concerns near looper",
);

console.log("=== looper validate-skill (skills library) ===");
for (const n of notes) console.log(`  ${n}`);
if (failures.length) {
  console.error("\nFAILURES:");
  for (const f of failures) console.error(`  - ${f}`);
  console.error(`\n${failures.length} failure(s)`);
  process.exit(1);
}
console.log("\nALL CHECKS PASSED");
process.exit(0);
