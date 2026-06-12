---
name: tap-in
description: Initialize session with context briefing (team-aware)
context: fork
allowed-tools: Bash, Read, Glob, Write
---

# Tap In - Session Initialization

Read recent activity and current state to get oriented at session start. **Team-aware**: Detects experimental agent teams and provides team coordination guidance.

## Workflow

### 1. Check Session Capabilities

```bash
# Check if experimental agent teams are enabled
claude config get experimental.agentTeams 2>/dev/null || echo "teams_disabled"
```

**Set flag**: `TEAMS_ENABLED=true/false` for subsequent steps

---

### 2. Get Current Date

```bash
date +%Y-%m-%d
```

---

### 3. Check if Daily Housekeeping Needed

```bash
head -1 /root/projects/Ditto/DaysActivity.md 2>/dev/null
```

- If date doesn't match today: Run `/daily-housekeeping` first
- STOP here until housekeeping completes
- Then resume tap-in

---

### 4. Read Recent Activity

**Last 2-3 entries from DaysActivity.md**:
- Note open work items
- Note recent state/issues
- Identify continuity threads
- **TEAMS**: Look for team mentions (Team Alpha, Team Beta, etc.)

```bash
head -80 /root/projects/Ditto/DaysActivity.md
```

---

### 5. Read CurrentStatus.md

```bash
cat /root/projects/Ditto/CurrentStatus.md
```

Get operational context.

---

### 5.5. Check Zepo-Pulse Heartbeat

Detect whether last night's `pulse-zepos` run completed. If the heartbeat file
is missing or older than 25h, file a P1 bead so the morning session surfaces
the failure in the next step's open-bead listing. **Non-fatal**: any error
here is swallowed so /tap-in continues.

```bash
# Zepo-pulse heartbeat staleness check (co-vle).
# 90000s ≈ 25h, giving a small grace beyond the 24h cron cadence.
{
    HEARTBEAT_LIB=/root/projects/Ditto/.claude/skills/pulse-zepos/lib/zepo-heartbeat.sh
    if [[ -r "$HEARTBEAT_LIB" ]]; then
        # shellcheck source=/dev/null
        source "$HEARTBEAT_LIB"
        if zepo_heartbeat_is_stale 90000 2>/dev/null; then
            today="$(date -u +%Y-%m-%d)"
            # The pulse-run:<today> label is the idempotency key — any open bead
            # with that label is the (possibly already-filed) failure record.
            existing=$(bd list --label "pulse-run:$today" --status open --json 2>/dev/null \
                      | jq -r '.[].id' 2>/dev/null | head -1)
            if [[ -z "$existing" ]]; then
                yesterday="$(date -u -d 'yesterday' +%Y-%m-%d)"
                bd create "[zepo-pulse] last night's run failed (heartbeat stale)" \
                          -d "/var/moo/state/zepo-pulse-heartbeat.json missing or older than 25h. Inspect /var/moo/logs/pulse-runs/${yesterday}.log for failure context." \
                          --labels "pulse-run:$today" --priority P1 >/dev/null 2>&1 || true
            fi
        fi
    fi
} 2>/dev/null || true
```

If a P1 bead is filed here, it will appear in step 6's open-bead listing and
surface in the briefing's Open Beads section automatically.

### 5.6. Check Zepo Sync Failures

After checking heartbeat staleness, check whether the last pulse run had any
fork sync failures. These indicate zepos falling behind upstream — a standing
order is that upstream merges are accepted automatically, so sync failures
require immediate attention.

```bash
{
    HEARTBEAT_FILE="${ZEPO_HEARTBEAT_FILE:-/var/moo/state/zepo-pulse-heartbeat.json}"
    if [[ -f "$HEARTBEAT_FILE" ]]; then
        sync_failed=$(jq -r '.sync_failed // 0' "$HEARTBEAT_FILE" 2>/dev/null)
        sync_names=$(jq -r '.sync_failed_names // ""' "$HEARTBEAT_FILE" 2>/dev/null)
        if [[ "${sync_failed:-0}" -gt 0 ]]; then
            echo "SYNC_FAILURES=${sync_failed} (${sync_names})"
        fi
    fi
    SYNC_STATE="/var/moo/state/zepo-sync-failures.json"
    if [[ -f "$SYNC_STATE" ]]; then
        consecutive=$(jq -r 'to_entries[] | "\(.key): \(.value) consecutive"' "$SYNC_STATE" 2>/dev/null)
        if [[ -n "$consecutive" ]]; then
            echo "CONSECUTIVE_SYNC_FAILURES:"
            echo "$consecutive"
        fi
    fi
} 2>/dev/null || true
```

If sync failures exist, include them prominently in the briefing under a
**Sync Failures** heading — not buried in open beads. Upstream acceptance is
a standing order; blocked syncs mean the fork is diverging.

---

### 6. Check Open Beads

```bash
tail -30 /root/projects/Ditto/.beads/issues.jsonl | jq -r 'select(.status == "open") | [.id, .type, .title] | @tsv' | column -t
```

---

### 6.5. Check CM Search Substrate

Query CM health to distinguish three failure modes that all look the same to a caller:
(a) server down, (b) server up but empty index, (c) server up but stale index.

```bash
source /root/projects/Ditto/factory/factory.env 2>/dev/null
CM_PORT=${CM_PORT:-3002}
curl -s --max-time 3 "http://localhost:${CM_PORT}/api/v1/health" 2>/dev/null || echo '{"error":"unreachable"}'
```

Then classify:

- **No response / non-2xx** → CM server down. Flag: "memory search unavailable — start with `systemctl status claude-monitor`."
- **`conversationCount` missing from response** → server is pre-patch (old schema). Flag: "CM health endpoint predates co-s5e patch; apply `factory/patches/claude-monitor/001-health-endpoint-db-stats.patch` for richer signals."
- **`conversationCount == 0`** → DB is empty. Flag: "CM index is empty — run `cd /root/projects/claude-monitor && bun run backfill` to seed."
- **`lastEntryTimestamp` > 24h old** → backfill stale. Flag: "CM index hasn't absorbed new content in >24h. Check `/tmp/cm-backfill.log` and the crontab."
- **Otherwise** → CM is healthy; no warning needed.

Include any warning in the **Current State** section of the briefing.

---

### 7. Team State Analysis (if TEAMS_ENABLED)

**7a. Scan beads for team assignments**:

```bash
# Get all open beads with team metadata
jq -r 'select(.status == "open") | [.id, .title, .metadata.team // "none", .metadata.priority // "none"] | @tsv' \
  /root/projects/Ditto/.beads/issues.jsonl | column -t
```

**7b. Group beads by team**:

```bash
# Count beads per team
jq -r 'select(.status == "open" and .metadata.team) | .metadata.team' \
  /root/projects/Ditto/.beads/issues.jsonl | sort | uniq -c
```

**7c. Identify ready-to-launch teams**:

Teams with open beads assigned and no blocking dependencies.

---

### 7.5. Archive Previous Briefing and Increment Session Counter

```bash
# Archive previous briefing (if it exists) before overwriting
BRIEFING=/root/projects/Ditto/session-briefing.md
if [ -f "$BRIEFING" ]; then
  PREV_TS=$(head -1 "$BRIEFING" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' | tr ' :' '--')
  PREV_TS=${PREV_TS:-$(date -r "$BRIEFING" +%Y-%m-%d-%H%M)}
  cp "$BRIEFING" "/root/projects/Ditto/archive/session-briefing-${PREV_TS}.md"
fi

# Increment session counter
COUNTER_FILE=/root/projects/Ditto/.runtime/session-counter
SESSION_N=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
SESSION_N=$((SESSION_N + 1))
echo "$SESSION_N" > "$COUNTER_FILE"
echo "Session #${SESSION_N}"
```

Store `SESSION_N` for use in the briefing header.

---

### 8. Output Session Briefing

**Write to**: `/root/projects/Ditto/session-briefing.md`

```markdown
## Session Briefing #N - YYYY-MM-DD HH:MM

---

### Summary

**Last Session**: [timestamp] - [brief summary from most recent handoff]

**Current State**: [branch, backend config, operational health — concise bullets]

**Open Work (carried forward)**:
- [item 1 — what it is and why it's still open]
- [item 2]

---

### Action Items

Prioritized next steps. Each line starts with the digit, two spaces, then the
text — this is the trigger format that desk-invoke.sh matches (`^N  `).
Do NOT use markdown numbered-list syntax (`1. **bold**`). The raw digit prefix
is what makes items hotkey-invocable in the CONTENT pane.

1  [specific action — what to do and why it's next] (bead-id)
2  [specific action] (bead-id)
3  [specific action] (bead-id)

---

### Ready Status

[Ready to proceed | Issues require attention]
```

**Structure notes:**
- **Summary** = what happened, where we are, what's still open. Read-only context.
- **Action Items** = what to do next. These are hotkey-addressable in the steves-desk
  viewer — Steve can jump to any item and close it when reviewed.
- **No Open Beads table** — that belongs in the Beads window of steves-desk, not here.
  The tap-in skill still reads beads for context, but the briefing surfaces them as
  action items when they need attention, not as a raw table.

---

### 8.5. Ensure Steve's Desk Session Is Running

```bash
/root/projects/Ditto/tmuxMOO/bin/steves-desk-session.sh
```

Idempotent — exits immediately if steves-desk is already up, creates it if
not. The desk must be running before step 9 can register anything.

---

### 9. Register Briefing with Steve's Desk

```bash
/root/projects/Ditto/tmuxMOO/bin/desk-register.sh System session-briefing.md
```

Ensures the session-briefing.md is in the StevesDocs manifest so it appears
in the steves-desk System window. Idempotent — safe to run on every tap-in.

---

## Pairs With

- `/handoff` - Session end (records team state)
- `/daily-housekeeping` - Runs before tap-in if date changed

## Re-run Anytime

This skill can be invoked mid-session to refresh context:
```
/tap-in
```
