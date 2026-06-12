#!/usr/bin/env bash
# .claude/skills/checkpoint/checkpoint.sh
#
# Mini session checkpoint — writes .claude/state/checkpoint.json with the
# current git working-tree state and in-progress bead list. Skips the write
# entirely when nothing has changed since the prior checkpoint AND the prior
# checkpoint is less than 6 hours old (force-refresh window).
#
# Invoked synchronously by the /checkpoint skill (typically via /loop 30m /checkpoint).
# No subagent. Runs in ~1 second.

set -eu
# Note: deliberately not enabling pipefail. Several jq pipelines below pipe
# into `tail -1`, and tail closing the pipe early triggers SIGPIPE in jq,
# which would kill the script under pipefail. The subsequent commands are
# defensively scripted (|| true, 2>/dev/null) so a missing value doesn't break us.

REPO_DIR="${CLAUDE_PROJECT_DIR:-/root/projects/Ditto}"
ZGENT="$(basename "$REPO_DIR")"
STATE_DIR="$REPO_DIR/.claude/state"
CHECKPOINT_FILE="$STATE_DIR/checkpoint.json"
LOG_FILE="/var/moo/logs/sessions.jsonl"
FORCE_REFRESH_SECONDS=21600   # 6 hours — write a fresh checkpoint at least this often
MIN_INACTIVE_SECONDS=${CHECKPOINT_MIN_INACTIVE:-300}   # 5 minutes — skip during active exchange

mkdir -p "$STATE_DIR"

NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
NOW_HHMM="$(date -u +%H:%M)"
NOW_EPOCH="$(date -u +%s)"

# --- Smoke checks (always run, even when checkpoint skips) -------------------
SMOKE_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/smoke-check.sh"
if [[ -x "$SMOKE_SCRIPT" ]]; then
  ZGENT="$ZGENT" bash "$SMOKE_SCRIPT" || true
fi
# --- End smoke checks -------------------------------------------------------

# --- Inactivity check ----------------------------------------------------
# Skip the checkpoint when the user is actively engaged in a conversation.
# Activity = the timestamp of the most recent transcript entry from BEFORE
# this current /checkpoint cron invocation. (We look "before this invocation"
# because the cron firing itself adds entries; using raw mtime would always
# look "active.")

SANITIZED_CWD="$(echo "$REPO_DIR" | sed 's|/|-|g')"
TRANSCRIPT_DIR="/root/.claude/projects/$SANITIZED_CWD"
LATEST_TRANSCRIPT="$(ls -t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)"

if [[ -n "$LATEST_TRANSCRIPT" && -f "$LATEST_TRANSCRIPT" ]]; then
  # Timestamp of the most recent /checkpoint cron injection (= start of THIS run).
  CURRENT_CRON_TS="$(jq -r 'select(.type == "user"
        and (.message.content | type) == "string"
        and (.message.content | contains("<command-name>/checkpoint")))
      | .timestamp' "$LATEST_TRANSCRIPT" 2>/dev/null | tail -1)"

  # Most recent transcript entry strictly BEFORE that — that's the prior conversation activity.
  if [[ -n "$CURRENT_CRON_TS" ]]; then
    PRIOR_ACTIVITY_TS="$(jq -r --arg cur "$CURRENT_CRON_TS" '
        select((.type == "user" or .type == "assistant") and .timestamp != null and .timestamp < $cur)
        | .timestamp' "$LATEST_TRANSCRIPT" 2>/dev/null | tail -1)"
  else
    # No /checkpoint injection found — checkpoint was invoked manually or this is a fresh session.
    PRIOR_ACTIVITY_TS="$(jq -r '
        select((.type == "user" or .type == "assistant") and .timestamp != null)
        | .timestamp' "$LATEST_TRANSCRIPT" 2>/dev/null | tail -1)"
  fi

  if [[ -n "$PRIOR_ACTIVITY_TS" ]]; then
    PRIOR_EPOCH="$(date -d "$PRIOR_ACTIVITY_TS" +%s 2>/dev/null || echo 0)"
    INACTIVE_FOR=$((NOW_EPOCH - PRIOR_EPOCH))
    if [[ $INACTIVE_FOR -lt $MIN_INACTIVE_SECONDS ]]; then
      jq -n -c \
        --arg ts "$NOW_UTC" \
        --arg sid "${CLAUDE_SESSION_ID:-unknown}" \
        --arg zgent "$ZGENT" \
        --arg event "checkpoint_skipped" \
        --arg reason "session_active" \
        --argjson inactive_for_seconds "$INACTIVE_FOR" \
        --argjson threshold "$MIN_INACTIVE_SECONDS" \
        '{ts:$ts, session_id:$sid, zgent:$zgent, event:$event, reason:$reason, inactive_for_seconds:$inactive_for_seconds, threshold:$threshold}' \
        >> "$LOG_FILE" 2>/dev/null || true
      echo "Checkpoint skipped — session active (last activity ${INACTIVE_FOR}s ago, threshold ${MIN_INACTIVE_SECONDS}s) [$NOW_HHMM]"
      exit 0
    fi
  fi
fi
# --- End inactivity check ------------------------------------------------

# Capture current state
BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
DIRTY="$(git -C "$REPO_DIR" status --porcelain 2>/dev/null | head -20 || true)"
DIFFSTAT="$(git -C "$REPO_DIR" diff --stat HEAD 2>/dev/null | tail -1 || true)"
# Filter out Dolt journal-writer warnings (legacy noise post-Dolt-disable) and the trailing summary line
BEADS="$(bd list --status in_progress 2>/dev/null | grep -E '^[◐○●✓❄]' | head -10 || true)"

# Hash current state for comparison
CUR_HASH="$(printf '%s\n%s\n%s\n%s\n' "$BRANCH" "$DIRTY" "$DIFFSTAT" "$BEADS" | sha1sum | awk '{print $1}')"

# Compare against prior checkpoint
SKIP="false"
PRIOR_TS=""
if [[ -f "$CHECKPOINT_FILE" ]]; then
  PRIOR_HASH="$(jq -r '.activity_hash // ""' "$CHECKPOINT_FILE" 2>/dev/null || true)"
  PRIOR_TS="$(jq -r '.timestamp // ""' "$CHECKPOINT_FILE" 2>/dev/null || true)"
  if [[ -n "$PRIOR_TS" && -n "$PRIOR_HASH" ]]; then
    PRIOR_EPOCH="$(date -d "$PRIOR_TS" +%s 2>/dev/null || echo 0)"
    AGE=$((NOW_EPOCH - PRIOR_EPOCH))
    if [[ "$CUR_HASH" == "$PRIOR_HASH" && "$AGE" -lt "$FORCE_REFRESH_SECONDS" ]]; then
      SKIP="true"
    fi
  fi
fi

if [[ "$SKIP" == "true" ]]; then
  # No activity. Log the heartbeat but don't rewrite the file.
  jq -n -c \
    --arg ts "$NOW_UTC" \
    --arg sid "${CLAUDE_SESSION_ID:-unknown}" \
    --arg zgent "$ZGENT" \
    --arg event "checkpoint_skipped" \
    --arg reason "no_activity_since_prior" \
    '{ts:$ts, session_id:$sid, zgent:$zgent, event:$event, reason:$reason}' \
    >> "$LOG_FILE" 2>/dev/null || true
  echo "Checkpoint skipped — no activity since $PRIOR_TS [$NOW_HHMM]"
  exit 0
fi

# State changed (or force-refresh window crossed). Write a fresh checkpoint.
DIRTY_FILES_JSON="$(printf '%s' "$DIRTY" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
BEADS_JSON="$(printf '%s' "$BEADS" | jq -R -s -c 'split("\n") | map(select(length > 0))')"

DIRTY_COUNT="$(printf '%s' "$DIRTY" | grep -c '^' 2>/dev/null || echo 0)"
BEADS_COUNT="$(printf '%s' "$BEADS" | grep -c '^' 2>/dev/null || echo 0)"
NOTE="Auto-checkpoint. Dirty files: ${DIRTY_COUNT}. In-progress beads: ${BEADS_COUNT}. Diff: ${DIFFSTAT:-clean}."

jq -n \
  --arg zgent "$ZGENT" \
  --arg ts "$NOW_UTC" \
  --arg branch "$BRANCH" \
  --argjson dirty_files "$DIRTY_FILES_JSON" \
  --arg diff_stat "$DIFFSTAT" \
  --argjson beads "$BEADS_JSON" \
  --arg note "$NOTE" \
  --arg hash "$CUR_HASH" \
  '{
    zgent: $zgent,
    timestamp: $ts,
    type: "checkpoint",
    git: {branch: $branch, dirty_files: $dirty_files, diff_stat: $diff_stat},
    beads: {in_progress: $beads},
    note: $note,
    activity_hash: $hash
  }' > "$CHECKPOINT_FILE"

jq -n -c \
  --arg ts "$NOW_UTC" \
  --arg sid "${CLAUDE_SESSION_ID:-unknown}" \
  --arg zgent "$ZGENT" \
  --arg event "checkpoint" \
  '{ts:$ts, session_id:$sid, zgent:$zgent, event:$event}' \
  >> "$LOG_FILE" 2>/dev/null || true

echo "Checkpoint saved [$NOW_HHMM]"
