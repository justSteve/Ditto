#!/usr/bin/env bash
# .claude/skills/checkpoint/smoke-check.sh
#
# Lightweight WSL + GC smoke checks. Runs on every checkpoint tick
# (even when the checkpoint itself skips). Checks system health markers
# and takes remedial action for known failure modes.
#
# Returns 0 always (smoke check failures are logged, not fatal).
# Prints one line per finding; prints nothing when clean.

set -eu

LOG_FILE="${SMOKE_CHECK_LOG:-/var/moo/logs/smoke-check.jsonl}"
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
ZGENT="${ZGENT:-COO}"

# Thresholds (tunable via env)
BD_BIN_WARN=${BD_BIN_WARN:-20}
BD_BIN_KILL=${BD_BIN_KILL:-50}
MEM_AVAIL_WARN_MB=${MEM_AVAIL_WARN_MB:-2048}
DOLT_CPU_WARN=${DOLT_CPU_WARN:-200}

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

_log() {
    local severity="$1" check="$2" detail="$3"
    jq -n -c \
        --arg ts "$NOW_UTC" --arg zgent "$ZGENT" \
        --arg severity "$severity" --arg check "$check" --arg detail "$detail" \
        '{ts:$ts, zgent:$zgent, event:"smoke_check", severity:$severity, check:$check, detail:$detail}' \
        >> "$LOG_FILE" 2>/dev/null || true
}

findings=0

# --- 1. bd-bin process count ------------------------------------------------
bd_count=$(pgrep -c -f '/usr/local/lib/bd-bin' 2>/dev/null) || bd_count=0

if [[ "$bd_count" -ge "$BD_BIN_KILL" ]]; then
    pkill -9 -f '/usr/local/lib/bd-bin' 2>/dev/null || true
    _log "critical" "bd-bin-flood" "killed $bd_count bd-bin processes (threshold: $BD_BIN_KILL)"
    echo "SMOKE: killed $bd_count bd-bin zombies (flood detected)"
    findings=$((findings + 1))
elif [[ "$bd_count" -ge "$BD_BIN_WARN" ]]; then
    _log "warning" "bd-bin-elevated" "bd-bin count=$bd_count (warn threshold: $BD_BIN_WARN)"
    echo "SMOKE: bd-bin count elevated ($bd_count processes)"
    findings=$((findings + 1))
fi

# --- 2. Memory pressure ----------------------------------------------------
mem_avail_kb=$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
mem_avail_mb=$((mem_avail_kb / 1024))

if [[ "$mem_avail_mb" -lt "$MEM_AVAIL_WARN_MB" ]]; then
    mem_total_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
    mem_used_mb=$(( (mem_total_kb - mem_avail_kb) / 1024 ))
    mem_total_mb=$((mem_total_kb / 1024))
    _log "warning" "memory-pressure" "available=${mem_avail_mb}MB used=${mem_used_mb}MB total=${mem_total_mb}MB"
    echo "SMOKE: low memory (${mem_avail_mb}MB available of ${mem_total_mb}MB)"
    findings=$((findings + 1))
fi

# --- 3. Dolt CPU ------------------------------------------------------------
dolt_cpu=$(ps -C dolt -o %cpu= 2>/dev/null | awk '{sum+=$1} END {printf "%d", sum+0}' || echo 0)

if [[ "$dolt_cpu" -ge "$DOLT_CPU_WARN" ]]; then
    _log "warning" "dolt-cpu-high" "dolt aggregate CPU=${dolt_cpu}% (threshold: ${DOLT_CPU_WARN}%)"
    echo "SMOKE: dolt CPU high (${dolt_cpu}%)"
    findings=$((findings + 1))
fi

# --- 4. Swap pressure (early warning for OOM) --------------------------------
swap_total_kb=$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
swap_used_kb=$(( swap_total_kb - $(awk '/SwapFree/ {print $2}' /proc/meminfo 2>/dev/null || echo 0) ))
swap_used_mb=$((swap_used_kb / 1024))
swap_warn_mb=${SWAP_USED_WARN_MB:-4096}

if [[ "$swap_total_kb" -gt 0 && "$swap_used_mb" -ge "$swap_warn_mb" ]]; then
    _log "warning" "swap-pressure" "swap used=${swap_used_mb}MB (threshold: ${swap_warn_mb}MB)"
    echo "SMOKE: high swap usage (${swap_used_mb}MB)"
    findings=$((findings + 1))
fi

# --- 5. GC supervisor alive check -------------------------------------------
if ! pgrep -f 'gc supervisor run' >/dev/null 2>&1; then
    if systemctl --user is-enabled gascity-supervisor.service >/dev/null 2>&1; then
        _log "warning" "supervisor-down" "gc supervisor not running but systemd unit is enabled"
        echo "SMOKE: gc supervisor not running"
        findings=$((findings + 1))
    fi
fi

# --- Summary log (always, even when clean) -----------------------------------
_log "info" "summary" "checks=5 findings=$findings bd_bin=$bd_count mem_avail=${mem_avail_mb}MB dolt_cpu=${dolt_cpu}% swap=${swap_used_mb}MB"

exit 0
