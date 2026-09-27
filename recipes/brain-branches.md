---
id: brain-branches
name: Brain Branches
version: 0.1.0
description: Speculative memory for GBrain. Run the brain in a smolmachines microVM so it can be forked live in under a second and checkpointed; explore options in isolated branches, merge back only the one that holds up, and rewind any merge that proves wrong.
category: reflex
requires: []
secrets: []
health_checks:
  - type: command
    argv: ["smolvm", "--version"]
    label: "smolmachines runtime"
  - type: command
    argv: ["gbrain-branch", "help"]
    label: "gbrain-branch CLI"
setup_time: 5 min
cost_estimate: "$0 (runs on your own machine)"
---

# Brain Branches: Speculative Memory

Every exploration an agent runs writes into the brain, including the ones
that turn out to be wrong. Brain Branches forks the whole running brain (its
pages, links, index and processes) once per option. An agent explores in each
fork, and only the fork that earns it is merged back. The others are thrown
away and leave nothing in the brain.

A fork is a copy-on-write clone of the microVM the brain runs in, made by
[smolmachines](https://smolmachines.com) in under a second. The brain's own git
repo carries the merge, so history shows which branch a page came from.

## IMPORTANT: Instructions for the Agent

**You are the installer.** Verify after each step.

1. **Install smolmachines** (Linux with KVM, or macOS on Apple Silicon):

   ```sh
   curl -sSL https://smolmachines.com/install.sh | bash
   smolvm --version
   ```

2. **Install the CLI:** put `gbrain-branch` on `PATH` and check it with
   `gbrain-branch help`.

3. **Create the brain machine,** or move an existing brain into one:

   ```sh
   gbrain-branch init brain
   ```

   This boots a branchable microVM, installs GBrain in it, and initializes a
   PGLite brain whose markdown repo is `/brain`. To bring existing pages, copy
   them in and run `gbrain import /brain --no-embed` inside it.

4. **Install the skill:** copy `skills/brain-branches/` into the brain's
   skills directory and register it in that directory's `manifest.json`:

   ```json
   {"name": "brain-branches", "path": "brain-branches/SKILL.md",
    "description": "Speculative memory: fork the brain per option, merge the winner."}
   ```

   Then `gbrain check-resolvable` must report no errors for it.

5. **Verify:** `gbrain-branch fork brain brain-check && gbrain-branch discard brain-check`
   must complete in a few seconds.

## Notes

- The brain keeps serving while it is forked; forks do not pause it.
- Forks share the brain's disk pages until they write, so each costs only
  what it changes.
- Merges are git merges. A conflict stops the merge instead of overwriting.
- Every merge checkpoints the brain first, RAM included, so `gbrain-branch rewind`
  can put the whole brain back (pages, index, links) if a merge proves wrong.
  Checkpoints deduplicate: after the first, each stores only what changed.
- API keys stay outside the VM. `smolvm machine create --credential …` gives
  the brain and every fork a placeholder, and the host swaps in the real key on
  HTTPS requests to the named hosts only.
