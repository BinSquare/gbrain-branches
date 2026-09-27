# Brain Branches: speculative memory for GBrain

A GBrain extension that lets an agent **fork its live brain once per option,
explore each option in isolation, and merge back only the branch that holds up**.
Losing explorations leave nothing in the brain. If a merged decision later proves
wrong, **rewind the whole brain to just before that merge**.

Today every exploration an agent runs writes into [GBrain](https://github.com/garrytan/gbrain),
wrong turns included, and later sessions trust those pages. Brain Branches gives
each option its own complete copy of the running brain: pages, typed links, the
PGLite index, and the processes serving it. That copy is a copy-on-write fork of the
[smolmachines](https://smolmachines.com) microVM the brain lives in, made in under
a second while the brain keeps serving. The merge is a git merge into the brain's
own markdown repo, followed by `gbrain import` and `gbrain extract`, so the winning
pages land wired into the graph and git history records which branch they came from.

It plugs into GBrain the way GBrain's own integrations do:

| Piece | Path | Role |
|---|---|---|
| Recipe | `recipes/brain-branches.md` | Installer instructions an agent follows, with health checks, in GBrain's recipe format |
| Skill | `skills/brain-branches/SKILL.md` | The procedure an agent runs for a multi-option decision: frame, fork, explore brain-first, compare, merge, verify |
| CLI | `gbrain-branch` | `init`, `fork`, `exec`, `write`, `diff`, `merge`, `discard`, `list`, `checkpoint`, `log`, `rewind` |
| Agent | `agent.ts` | Claude following the skill, with `gbrain-branch` as its only tool |

## Run the demo

```sh
./gbrain-branch init brain   # once: branchable microVM + GBrain + PGLite brain at /brain
./demo.sh                    # ~45 s
```

An agent follows the skill on a real GBrain (0.59):

1. **The question:** `gbrain query` finds the goal page in the brain.
2. **Fork:** the live brain is forked three ways, one per launch strategy. Each fork
   takes about 0.8 s.
3. **Explore:** in each branch, in parallel, the agent queries its own copy, then writes
   a finding that links to `[[facts/goal]]` with a scored rationale, and re-indexes.
4. **Isolation:** a `gbrain get` matrix shows each branch knows only its own finding,
   and the brain knows none of them.
5. **Compare:** `gbrain-branch diff` lists what each branch learned since it forked.
6. **Merge and discard:** the winner is merged; the other branches are deleted.
7. **Verify:** the brain has the winning page, `gbrain backlinks facts/goal` now
   includes it, and the discarded options are gone from the brain.
8. **Rewind:** the decision proves wrong, and the brain is put back to the checkpoint
   taken just before the merge. The page and its links are gone, and the rewind can
   itself be undone.

## Rewind: undo a mistake in the brain

GBrain keeps whatever it is told. When a merged conclusion turns out to be wrong,
patching pages by hand leaves the index, links and later pages that built on it
inconsistent. Brain Branches checkpoints the whole running brain (pages, index,
links, RAM) before every merge, so the fix is one command:

```sh
gbrain-branch log brain                                   # newest first
gbrain-branch rewind brain before-merge-brain-hn-1790549679
gbrain-branch checkpoint brain before-migration           # before any risky change
```

- A checkpoint takes about 4 s and pauses the brain for about 30 ms.
- A rewind takes about 8 s, and the restored brain can be forked at once.
- A rewind checkpoints first, so it can itself be undone.
- Checkpoints deduplicate: after the first (about 630 MB for a small brain), each
  stores only what changed.

In a recorded run, one agent session merged a decision. A second session, told only
that the decision had failed, found the merge's checkpoint with `log` and rewound
the brain on its own.

## Run it with a real agent

```sh
ANTHROPIC_API_KEY=... bun agent.ts "How should we get the most developer signups by Friday?"
```

`agent.ts` gives Claude the skill as its instructions and a single tool that runs
`gbrain-branch` commands; nothing about the decision is scripted. In a recorded
run, the agent:
- chose three options;
- forked the brain once per option;
- ran `gbrain query` in each branch;
- wrote a scored finding linked to `[[facts/goal]]` in each;
- diffed them, merged the best supported one, discarded the others;
- checked `gbrain backlinks` in the brain.

The key is used only by the agent on the host. Each branch's VM never sees it.

## 60-second pitch

- "Own your intelligence" means your agent's memory is plain files on a machine you
  own. GBrain gives you the files. Brain Branches gives the memory version control
  that works on a *running* brain.
- Agents shouldn't think in a straight line. Here the agent forks its whole brain
  three ways in under a second each, while the brain keeps serving.
- Each branch explores for real and writes real pages, and they're isolated: one
  branch's wrong turn never reaches another, or the brain.
- The winner merges back through git, because GBrain's memory *is* git, and lands
  linked into the graph. The losers leave nothing behind.
- And when a decision turns out wrong a week later, the agent rewinds the whole
  brain to just before it merged: pages, index and links together.
- Same idea at any scale: many agents, one brain, no one stepping on anyone's memory.
  API keys stay on the host, so the agent can use them but never read them.

## Notes

- Runs on Linux with KVM and on macOS (Apple Silicon), with the system's own bash 3.2
  and BSD tools. Keep about 5 GB free: each fork and checkpoint writes only what
  changed, but the first checkpoint of a brain is about 630 MB.
- `agent.ts` needs [Bun](https://bun.sh) (`curl -fsSL https://bun.sh/install | bash`).
- `demo.sh` scripts the explorations so it runs offline; `agent.ts` is the real thing.
- Each live fork adds a copy-on-write disk layer to the brain machine, and smolmachines
  caps a machine at 32. A `demo.sh` or `agent.ts` run uses three. When the cap is
  reached, `gbrain-branch fork` says so; rebuild with `gbrain-branch init` and
  re-import the pages.
- Scale check, with GBrain's own docs imported (274 pages, 2,200 chunks, 137 MB index):
  - a fork takes about 1 s and a query in a branch 1.2 s;
  - a write takes 6 s and a merge 7–8 s;
  - only changed pages are re-indexed, and deletes propagate.
