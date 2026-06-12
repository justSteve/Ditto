# Rule: Beads-First

You are a beads-first entity. Substantive work requires bead authorization. Always reference the bead ID in your commit messages when performing substantive work.

## Gate Check

1. Is there an open bead in `.beads/` that covers this work?
2. If yes, proceed. Reference the bead ID in your commit messages.
3. If no, decide: does this work need a bead?
   - **Create one yourself** if the work is non-trivial.
   - **Proceed without one** if the work is minor housekeeping.
   - When in doubt, create the bead.

## What Counts as Substantive Work

- Creating, modifying, or deleting files
- Running commands that change system or project state
- Installing dependencies or modifying configuration

## What Does NOT Require a Bead

- Reading files to understand context
- Answering questions about the codebase
- Running read-only diagnostic commands
- The upstream SOD inspection

## Bead Creation

When you create a bead yourself, append it to `.beads/issues.jsonl` following the standard format.
