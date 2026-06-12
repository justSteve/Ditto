---
name: checkpoint
description: Mini session checkpoint — auto-save state for crash recovery
allowed-tools: Bash
---

# Checkpoint — Mini Session Save

Lightweight state capture invoked by `/loop 30m /checkpoint`. Skips automatically when nothing has changed since the prior checkpoint.

**Keep this fast and quiet.** Minimal output to the user.

## Execution

Run the checkpoint script in the main session:

```bash
bash "${CLAUDE_PROJECT_DIR:-/root/projects/Ditto}/.claude/skills/checkpoint/checkpoint.sh"
```

That's it. The script does its own work synchronously in ~1 second. No subagent.

## How it works

The script applies two skip checks in order, then falls through to a write.

### 1. Inactivity skip (the "active conversation" guard)

Reads the current Claude Code transcript at `~/.claude/projects/<sanitized-cwd>/<session-id>.jsonl`. Finds the timestamp of the most recent `/checkpoint` cron injection (= when *this* tick started). Then finds the most recent transcript entry strictly **before** that timestamp — that's the prior conversation activity.

If `(now - prior_activity) < MIN_INACTIVE_SECONDS` (default 300s; override with `CHECKPOINT_MIN_INACTIVE`), the session is actively engaged and the checkpoint skips. Logs a `checkpoint_skipped` event with `reason: "session_active"` and the actual inactivity gap.

Looking *before* the current cron injection matters: the cron firing itself updates the transcript, so naive mtime checks would always look "active."

### 2. Activity-hash skip (the "no state change" guard)

Reads the prior `.claude/state/checkpoint.json` and grabs its `activity_hash`. Computes the sha1 of `(branch, dirty files, diff stat, in-progress beads)` for the current state. If they match **and** the prior checkpoint is less than 6 hours old (`FORCE_REFRESH_SECONDS`), logs `reason: "no_activity_since_prior"` and skips.

The 6-hour force-refresh keeps the timestamp from going stale across a long idle.

### 3. Write

If neither skip fires, rewrites `checkpoint.json` with fresh content (including the new `activity_hash`) and logs a `checkpoint` event.

### Output

One line:

- `Checkpoint saved [HH:MM]` — wrote a fresh checkpoint.
- `Checkpoint skipped — session active (last activity Ns ago, threshold Ns) [HH:MM]` — inactivity guard.
- `Checkpoint skipped — no activity since <prior_ts> [HH:MM]` — hash guard.

## Why no subagent

The original design spawned a background `Agent` for every tick to "keep the main conversation flowing." In practice the subagent overhead (~50s + permission denials in many session contexts) was far more disruptive than a synchronous ~1s shell call. The script reads the project's allowlist (which already has broad coverage of `bd`, `git`, `jq`, `find`, `mkdir`, etc.) and runs cleanly without any permission prompts.

## Recovery

The next `/tap-in` checks for `snapshot.json` (from `/handoff`) first, then `checkpoint.json`:

- **snapshot.json exists** → full warm start (from /handoff), ignore checkpoint
- **checkpoint.json exists, no snapshot** → partial warm start from auto-save; note it's from auto-checkpoint, not a proper handoff
- **neither exists** → cold start

## Notes

- Checkpoint does NOT replace `/handoff`. It's a safety net.
- The `activity_hash` field is the comparison baseline. Don't hand-edit it.
- When `/handoff` runs, it writes `snapshot.json` and the checkpoint becomes irrelevant for recovery.
- Both `.claude/state/checkpoint.json` and `.claude/state/snapshot.json` should be gitignored.
