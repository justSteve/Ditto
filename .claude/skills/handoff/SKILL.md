---
name: handoff
description: Prepend session handoff to DaysActivity.md (team-aware)
allowed-tools: Bash, Read, Write, Glob
---

# Create Session Handoff

Prepend a session handoff entry to `DaysActivity.md` (cumulative daily log). **Team-aware**: Records team progress when experimental agent teams are enabled.

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

3. **Check for experimental teams**
   ```bash
   claude config get experimental.agentTeams 2>/dev/null || echo "teams_disabled"
   ```
   - Set flag: TEAMS_ENABLED=true/false

4. **Gather team state** (if TEAMS_ENABLED)

   **4a. Team progress summary**:
   ```bash
   # Get team bead status
   jq -r 'select(.metadata.team) |
     [.metadata.team, .status, .id, .title] | @tsv' \
     /root/projects/Ditto/.beads/issues.jsonl | \
     sort | column -t
   ```

   **4b. Identify team transitions**:
   - Which beads were completed this session?
   - Which teams are now unblocked?
   - Which teams are ready to launch?

   ```bash
   # Recently completed beads (would need timestamp check)
   jq -r 'select(.status == "closed" and .metadata.team) |
     [.metadata.team, .id, .title] | @tsv' \
     /root/projects/Ditto/.beads/issues.jsonl
   ```

5. **Gather context**
   - Read `CurrentStatus.md` for current state
   - Review recent conversation for session summary
   - Note any discoveries or issues encountered
   - **TEAMS**: Note team progress, blockers resolved, new blockers

6. **Check open beads**
   ```bash
   tail -30 /root/projects/Ditto/.beads/issues.jsonl | jq -r 'select(.status == "open") | [.id, .type, .title] | @tsv' | column -t
   ```

7. **Create handoff entry**

   **Standard format** (when teams NOT enabled):

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

   **Team-aware format** (when teams enabled):

```markdown
## HH:MM - Session Handoff [Team Execution]

**Summary**: [1-2 sentence description of what was accomplished]

**Teams Active**: [count] ([list team names])

**Team Progress**:
- **Team Alpha**: Completed alpha.1, alpha.2. In progress: alpha.3 (2h remaining)
- **Team Beta**: Blocked on alpha.3, ready to launch after gate opens
- **Team Gamma**: Ready to launch (no blockers)
- **Team Epsilon**: epsilon.1 (MCP deployment) complete

**Team State Transitions**:
- Alpha.1 completed -> Alpha.2 now active
- Epsilon.1 completed -> MCP deployed and running

**Next Session Actions**:
- Resume Team Alpha: Complete alpha.3, alpha.4 (~4h)
- Launch Beta/Gamma/Delta in parallel once Alpha gate opens

**Open Work**:
- [Any non-team work items]

**Files Changed**:
path/to/file1.md
path/to/file2.ts

---
```

8. **Prepend to DaysActivity.md**
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

## Team-Specific Notes

When recording team handoffs:

**1. Team Progress**:
- List each active team
- Show completed beads and in-progress bead
- Estimate time remaining for in-progress work

**2. Team State Transitions**:
- Show causality (bead X completed -> team Y can now start)

**3. Next Session Actions**:
- Be specific: "Resume Team Alpha" is not enough
- Include: which bead, what's left, estimated duration
- Highlight ready-to-launch teams
- Note critical path dependencies

**Critical**: The handoff's "Next Session Actions" becomes tap-in's "Resumption Guidance"

