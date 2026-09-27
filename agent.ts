// A real agent that follows skills/brain-branches/SKILL.md on a live GBrain.
//
// Claude gets the skill as its instructions and one tool that runs
// `gbrain-branch` commands. It frames the options, forks the brain, explores
// each branch brain-first, writes linked findings, compares, merges the
// winner and verifies. Nothing about the decision is scripted.
//
//   ANTHROPIC_API_KEY=... bun agent.ts "<decision to make>"
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

const dir = import.meta.dir;
const brain = process.env.BRAIN ?? "brain";
const model = process.env.MODEL ?? "claude-sonnet-5";
const key = process.env.ANTHROPIC_API_KEY;
if (!key) throw new Error("set ANTHROPIC_API_KEY");
const question =
  process.argv[2] ??
  "How should we get the most developer signups for smolmachines by Friday?";
const skill = readFileSync(join(dir, "skills/brain-branches/SKILL.md"), "utf8");

const system = `You are an agent whose long-term memory is a GBrain brain running in the smol machine "${brain}".
Follow this skill exactly:

${skill}

Tools: \`gbrain_branch\` runs one gbrain-branch command (see its usage below). Use
\`gbrain-branch exec <machine> -- gbrain <args>\` for GBrain commands (query, get, list,
backlinks), and \`gbrain-branch write <machine> <slug>\` with page markdown to save a page.
Name branches ${brain}-<option>. Use 3 options. Pages you write need YAML frontmatter
(title, type: analysis, score: <1-10>) and must link to the pages they build on with [[slug]].
Keep each finding under 120 words. When done, reply with a short summary of which option
won and why, with no further tool calls.

gbrain-branch usage:
${spawnSync(join(dir, "gbrain-branch"), ["help"], { encoding: "utf8" }).stdout}`;

const tools = [
  {
    name: "gbrain_branch",
    description: "Run a gbrain-branch command. Returns its stdout, stderr and exit code.",
    input_schema: {
      type: "object",
      properties: {
        args: {
          type: "array",
          items: { type: "string" },
          description: 'Arguments after "gbrain-branch", e.g. ["fork", "brain", "brain-a"]',
        },
        stdin: {
          type: "string",
          description: "Standard input, used by `write` for the page markdown",
        },
      },
      required: ["args"],
    },
  },
];

type Block = { type: string; [k: string]: any };
const messages: { role: "user" | "assistant"; content: any }[] = [
  { role: "user", content: `Decision to make: ${question}` },
];

function runTool(input: { args: string[]; stdin?: string }): string {
  const allowed = ["fork", "exec", "write", "diff", "merge", "discard", "list", "checkpoint", "log", "rewind"];
  if (!Array.isArray(input.args) || !allowed.includes(input.args[0])) {
    return `refused: only ${allowed.join(", ")} are allowed`;
  }
  const r = spawnSync(join(dir, "gbrain-branch"), input.args, {
    input: input.stdin ?? "",
    encoding: "utf8",
    timeout: 300_000,
  });
  const out = `${r.stdout ?? ""}${r.stderr ?? ""}`.trim();
  return `exit ${r.status}\n${out.slice(0, 4000)}`;
}

for (let turn = 0; turn < 40; turn++) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": key,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({ model, max_tokens: 2048, system, tools, messages }),
  });
  const body: any = await res.json();
  if (!res.ok) throw new Error(`Anthropic API ${res.status}: ${JSON.stringify(body)}`);
  const content: Block[] = body.content;
  messages.push({ role: "assistant", content });
  for (const block of content) {
    if (block.type === "text" && block.text.trim()) console.log(`\n\x1b[36magent:\x1b[0m ${block.text.trim()}`);
  }
  const calls = content.filter((b) => b.type === "tool_use");
  if (calls.length === 0) break;
  const results = calls.map((call) => {
    const shown = ["gbrain-branch", ...call.input.args].join(" ");
    console.log(`\x1b[33m$ ${shown}\x1b[0m${call.input.stdin ? `  <<< ${call.input.stdin.split("\n").length} lines` : ""}`);
    const output = runTool(call.input);
    console.log(output.split("\n").slice(0, 8).map((l) => `  ${l}`).join("\n"));
    return { type: "tool_result", tool_use_id: call.id, content: output };
  });
  messages.push({ role: "user", content: results });
}
