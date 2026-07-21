---
name: handoff
description: Prepend session handoff to DaysActivity.md
allowed-tools: Bash, Read, Write, Glob
---

# Create Session Handoff

Prepend a session handoff entry to `DaysActivity.md` (cumulative daily log).

## Anti-Shadowing Rule

NEVER generate DaysActivity entries freeform. Only this skill writes to DaysActivity.md. Freeform summaries skip bead-status checks, timestamp formatting, and validation. If you need to record session state outside of this skill, use `bd remember` or `bd comment`.

## Workflow

1. **Get current date and time**
   ```bash
   date +%Y-%m-%d
   date +%H:%M
   ```

2. **Check if DaysActivity.md exists for today**
   ```bash
   head -1 /root/projects/Ditto/DaysActivity.md 2>/dev/null
   ```
   - If missing or wrong date: Create fresh file with today's header
   - If exists with today's date: Prepend new entry

3. **Gather context**
   - Read `CurrentStatus.md` for current state
   - Review recent conversation for session summary
   - Note any discoveries or issues encountered

4. **Check open beads**
   ```bash
   bd list --status open
   ```

5. **Create handoff entry**

```markdown
## HH:MM - Session Handoff [Brief Topic Tag]

**Summary**: [1-2 sentence description of what was accomplished]

**Open Work**:
- [In-progress item 1]
- [In-progress item 2]

**Tried** *(include only for debugging/investigation sessions)*:
- [Approach 1] → [result — why it worked or didn't]
- [Approach 2] → [result — why it worked or didn't]

**Files Changed**:
path/to/file1.md
path/to/file2.ts

---
```

6. **Prepend to DaysActivity.md**
   - Read existing content
   - Write: new entry + blank line + existing content
   - Preserve the `# DaysActivity - YYYY-MM-DD` header at top

## Entry Format Rules

- **Timestamp**: 24-hour format (HH:MM)
- **Summary**: Standalone sentence, no bullet
- **Files Changed**: One file per line, no bullets, relative paths
- **Separator**: `---` between entries

## Creating Fresh DaysActivity.md

If file doesn't exist or has wrong date:

```markdown
# DaysActivity - YYYY-MM-DD

## HH:MM - Session Handoff

[Entry content...]

---
```

## Post-Write Validation

After writing the entry, verify before reporting success:

1. **Timestamp present** — entry has `## HH:MM` header in 24-hour format
2. **Summary present** — `**Summary**:` line is a complete sentence, not a fragment
3. **Open work present** — if any beads are in-progress, `**Open Work**:` lists them
4. **Files listed** — if code was changed this session, `**Files Changed**:` is populated
5. **Tried section** — if this session involved debugging or investigation, `**Tried**:` captures approaches and outcomes

If any check fails, fix the entry before reporting success. Do not hand back a partial handoff.

## Notes

- Entries are **prepended** (newest on top)
- Keep summaries concise and actionable
- Evaluate importance when summarizing - not everything needs detailed logging
- Files changed section only if files were actually modified
- **Tried section**: Include when the session involved debugging, investigation, or troubleshooting. Failed approaches are the most expensive thing for the next session to rediscover. Each entry: what was tried, what happened, why it worked or didn't. Skip for straightforward sessions (deploys, config changes, clean implementations).

## Removed, deliberately

**Agent-teams detection and the team-aware handoff format.** A step near the top
used to run `claude config get experimental.agentTeams`. That call **hangs** on
Claude Code 2.1.216 — it never returns, even with stdin closed (verified: 20s
timeout, rc=124) — so it burned the Bash timeout on every handoff. The
team-state gathering it guarded ran `jq` against `.beads/issues.jsonl`, a file
that does not exist because the beads store is Dolt-backed, and nothing ever set
the flag that would have selected the team-aware entry format. A hang feeding a
no-op. Removed 2026-07-21 (co-kavq). `/tap-in` carried the same call.
