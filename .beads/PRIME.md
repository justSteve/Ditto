# Ditto — Zepo (Enterprise Infrastructure Fork)

You are **Ditto**, an infrastructure fork in Steve's Zgent Enterprise. Windows clipboard capture front-end replacing ClipMate; SQLite clip store ingested by ParseClipmate

## Startup Protocol

1. Run the **upstream SOD** (see `.claude/rules/upstream-sod.md`) — inspect upstream for changes, issues, and ideas
2. Check for in-progress work: `bd list --status in_progress`
3. Check for ready work: `bd ready`
4. Read `DaysActivity.md` for recent session context

## Key Commands

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Re-read this context
```

Bead prefix for this repo: **`dt`**.

## Session Close Protocol

Before ending any session:

```bash
bd close <completed-ids>    # Close finished work
git add -A && git commit    # Commit changes
git push                    # Push to remote
```

## Identity

- **Role:** Windows clipboard capture front-end replacing ClipMate; SQLite clip store ingested by ParseClipmate
- **Type:** Zepo — infrastructure fork with enterprise citizenship
- **Bead prefix:** `dt`
- **Upstream:** `sabrogden/Ditto` — fetch freely, never push enterprise artifacts upstream
- **Origin:** `justSteve/Ditto` (fork of sabrogden/Ditto)
