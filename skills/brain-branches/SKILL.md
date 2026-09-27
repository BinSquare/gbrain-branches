---
name: brain-branches
version: 0.1.0
description: Speculative memory. Before committing to one answer on an uncertain decision, fork the live brain once per option, explore each option inside its own branch, and merge only the branch whose findings hold up. Discarded branches leave nothing behind in the brain, and every merge can be rewound if it later proves wrong. Use when a decision has several plausible paths, when an exploration might write wrong or low-quality pages, or when several agents should work in parallel without stepping on each other's memory.
triggers:
  - "explore options in parallel"
  - "branch the brain"
  - "try each approach"
  - "speculative memory"
  - "what if we tried"
  - "undo that merge"
  - "rewind the brain"
mutating: true
writes_pages: true
writes_to:
  - analysis/
requires:
  - recipes/brain-branches.md
---

# brain-branches: Explore in Branches, Merge What Holds Up

> **Convention:** see [conventions/brain-first.md](../conventions/brain-first.md).
> Each branch starts brain-first: `gbrain query` its own copy before exploring.

## What this is

A brain normally learns one path at a time, and a bad exploration leaves bad
pages behind that later sessions trust. This skill gives every option its own
complete copy of the running brain (pages, links, index), explores them in
parallel, and merges back only the winner. Git history in the brain's repo
records which branch a page came from.

## Procedure

1. **Frame the decision.** Write the question and the options you will
   compare. One option per branch; two to five branches.

2. **Fork.** One branch per option. This is sub-second; the brain keeps
   serving while it forks.

   ```sh
   gbrain-branch fork <brain> <brain>-<option> ...
   ```

3. **Explore each branch independently**, brain-first:

   ```sh
   gbrain-branch exec <branch> -- gbrain query "<the question>"
   ```

   Write what you learn as a page under `analysis/<option>` with
   `gbrain-branch write <branch> analysis/<option> < page.md`, link it to the
   pages it builds on (`[[facts/goal]]`), and give it a `score:` in its
   frontmatter with a one-line reason. `write` commits and re-indexes. Never
   write into another branch.

4. **Compare.** Review what each branch learned:

   ```sh
   gbrain-branch diff <branch>
   ```

   Pick the branch whose findings are best supported. A tie means the question
   was framed badly: reframe it and fork again instead of merging two branches.

5. **Merge the winner, discard the rest.**

   ```sh
   gbrain-branch merge <winner>
   gbrain-branch discard <loser> ... <winner>
   ```

   Discard the winner too once it is merged: its pages now live in the brain,
   and a branch left running costs memory for nothing.

   A merge is a git merge into the brain's repo, re-indexed. If the brain
   learned something that conflicts with the branch while it was out, the merge
   stops and names the conflict. Resolve it; never overwrite it.

6. **Verify.** `gbrain get analysis/<winner>` and `gbrain backlinks <page>`
   in the brain show the merged page wired into the graph. The discarded
   options must not appear.

7. **Rewind a merge that proves wrong.** Every merge checkpoints the brain
   first, RAM included. If a merged page later turns out to be wrong, put the
   whole brain back to before that merge instead of patching pages by hand:

   ```sh
   gbrain-branch log <brain>                          # newest first
   gbrain-branch rewind <brain> before-merge-<branch>-<time>
   ```

   The rewind is itself undoable: it checkpoints the brain first as
   `before-rewind-<time>`. Merge or discard open branches before rewinding.
   Before a risky change outside this skill, take one yourself:
   `gbrain-branch checkpoint <brain> <label>`.

## Anti-patterns

- Merging several branches to "keep everything". The point is that losing
  explorations leave nothing behind.
- Exploring in the brain itself and forking afterwards. Fork first.
- Letting a branch run long enough to drift from the brain's current facts.
  Branches are for one decision, then merge or discard.
- Deleting or hand-editing pages to undo a bad merge. Rewind to the merge's
  checkpoint; the brain's pages, index and links go back together.
