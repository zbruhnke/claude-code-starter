#!/usr/bin/env bash
#
# Wiggum Enforcement Script
# Tracks and enforces stop conditions for the wiggum loop
#
# Usage:
#   wiggum-enforce.sh check-gate <gate-name> <status>  # Record gate result, check limit
#   wiggum-enforce.sh check-chunk <chunk-id>           # Check chunk iteration limit
#   wiggum-enforce.sh is-stopped                       # Exit 0 if stopped, 1 if running
#   wiggum-enforce.sh clear                            # Clear stop condition (with user confirmation)
#   wiggum-enforce.sh status                           # Show current enforcement status
#   wiggum-enforce.sh reset-gate <gate-name>           # Reset failure count for a gate
#   wiggum-enforce.sh reset-chunk <chunk-id>           # Reset iteration count for a chunk
#
# Exit Codes:
#   0 - Success / Running (or Stopped for is-stopped)
#   1 - Error / Running (for is-stopped)
#   2 - Stop condition triggered (blocks operation)
#

set -euo pipefail

STATUS_FILE=".wiggum-status.json"
CONFIG_FILE="wiggum.config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Ensure jq is available
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}" >&2
  exit 1
fi

# Check status file exists
check_status_file() {
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo -e "${YELLOW}Warning: $STATUS_FILE not found. Run wiggum-status.sh init${NC}" >&2
    return 1
  fi
  return 0
}

# Load limits from config or status file
get_limit() {
  local name="$1"
  local default="$2"

  # Try config file first
  if [[ -f "$CONFIG_FILE" ]]; then
    local val
    val=$(jq -r ".limits.$name // empty" "$CONFIG_FILE" 2>/dev/null)
    [[ -n "$val" ]] && echo "$val" && return
  fi

  # Fall back to status file
  if [[ -f "$STATUS_FILE" ]]; then
    local val
    val=$(jq -r ".limits.$name // empty" "$STATUS_FILE" 2>/dev/null)
    [[ -n "$val" ]] && echo "$val" && return
  fi

  echo "$default"
}

MAX_GATE_FAILURES=$(get_limit "max_gate_failures" 3)
MAX_CHUNK_ITERATIONS=$(get_limit "max_iterations_per_chunk" 5)

# ─────────────────────────────────────────────────────────────────────────────
# CHECK-GATE - Track gate result and check limit
# ─────────────────────────────────────────────────────────────────────────────
check_gate() {
  local gate="$1"
  local status="$2"

  check_status_file || return 1

  if [[ "$status" == "failed" ]]; then
    # Get current failure count
    local count
    count=$(jq -r ".gate_failure_counts.$gate // 0" "$STATUS_FILE")
    count=$((count + 1))

    # Update failure count
    jq --arg gate "$gate" --argjson count "$count" \
      '.gate_failure_counts[$gate] = $count' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

    echo -e "${YELLOW}Gate '$gate' failure count: $count/$MAX_GATE_FAILURES${NC}"

    # Check if limit exceeded
    if [[ "$count" -ge "$MAX_GATE_FAILURES" ]]; then
      trigger_stop "gate_failure" "{\"gate\": \"$gate\", \"count\": $count, \"limit\": $MAX_GATE_FAILURES}"
      echo ""
      echo -e "${RED}${BOLD}!! STOP CONDITION TRIGGERED !!${NC}"
      echo -e "${RED}Gate '$gate' has failed $count times (limit: $MAX_GATE_FAILURES)${NC}"
      echo ""
      echo -e "Options:"
      echo -e "  1. ${BLUE}wiggum-enforce.sh clear${NC}        - Clear stop and continue (requires user approval)"
      echo -e "  2. ${BLUE}wiggum-enforce.sh reset-gate $gate${NC} - Reset failure count"
      echo -e "  3. Review failures and fix the underlying issue"
      exit 2
    fi

  elif [[ "$status" == "passed" ]]; then
    # Reset failure count on success
    jq --arg gate "$gate" '.gate_failure_counts[$gate] = 0' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
    echo -e "${GREEN}Gate '$gate' passed - failure count reset${NC}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CHECK-CHUNK - Track chunk iteration and check limit
# ─────────────────────────────────────────────────────────────────────────────
check_chunk() {
  local chunk_id="$1"

  check_status_file || return 1

  # Get current iteration count
  local count
  count=$(jq -r ".chunk_iteration_counts[\"$chunk_id\"] // 0" "$STATUS_FILE")
  count=$((count + 1))

  # Update iteration count
  jq --arg id "$chunk_id" --argjson count "$count" \
    '.chunk_iteration_counts[$id] = $count' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

  echo -e "${BLUE}Chunk $chunk_id iteration: $count/$MAX_CHUNK_ITERATIONS${NC}"

  # Check if limit exceeded
  if [[ "$count" -gt "$MAX_CHUNK_ITERATIONS" ]]; then
    trigger_stop "chunk_iterations" "{\"chunk_id\": \"$chunk_id\", \"count\": $count, \"limit\": $MAX_CHUNK_ITERATIONS}"
    echo ""
    echo -e "${RED}${BOLD}!! STOP CONDITION TRIGGERED !!${NC}"
    echo -e "${RED}Chunk $chunk_id has exceeded $MAX_CHUNK_ITERATIONS iterations${NC}"
    echo ""
    echo -e "This usually means the chunk is too large or has unclear requirements."
    echo -e "Options:"
    echo -e "  1. ${BLUE}wiggum-enforce.sh clear${NC}         - Clear stop and continue"
    echo -e "  2. ${BLUE}wiggum-enforce.sh reset-chunk $chunk_id${NC} - Reset iteration count"
    echo -e "  3. Re-plan the chunk into smaller pieces"
    exit 2
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# TRIGGER-STOP - Set stop condition
# ─────────────────────────────────────────────────────────────────────────────
trigger_stop() {
  local reason="$1"
  local details="$2"

  jq --arg reason "$reason" --argjson details "$details" \
    '.stop_conditions.active = true |
     .stop_conditions.reason = $reason |
     .stop_conditions.triggered_at = (now | todate) |
     .stop_conditions.details = $details' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# IS-STOPPED - Check if stop condition is active
# ─────────────────────────────────────────────────────────────────────────────
is_stopped() {
  check_status_file || exit 1

  local stopped
  stopped=$(jq -r '.stop_conditions.active // false' "$STATUS_FILE")

  if [[ "$stopped" == "true" ]]; then
    local reason
    reason=$(jq -r '.stop_conditions.reason' "$STATUS_FILE")
    echo -e "${RED}STOPPED: $reason${NC}"
    exit 0
  else
    echo -e "${GREEN}RUNNING${NC}"
    exit 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# CLEAR - Clear stop condition (interactive)
# ─────────────────────────────────────────────────────────────────────────────
clear_stop() {
  check_status_file || return 1

  local stopped
  stopped=$(jq -r '.stop_conditions.active // false' "$STATUS_FILE")

  if [[ "$stopped" != "true" ]]; then
    echo -e "${GREEN}No active stop condition${NC}"
    return 0
  fi

  local reason details
  reason=$(jq -r '.stop_conditions.reason' "$STATUS_FILE")
  details=$(jq '.stop_conditions.details' "$STATUS_FILE")

  echo -e "${YELLOW}${BOLD}Current Stop Condition${NC}"
  echo -e "  Reason: ${RED}$reason${NC}"
  echo -e "  Details: $details"
  echo ""

  # Check if running interactively
  if [[ -t 0 ]]; then
    read -p "Clear stop condition and continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      return 1
    fi
  fi

  jq '.stop_conditions.active = false |
      .stop_conditions.reason = null |
      .stop_conditions.triggered_at = null |
      .stop_conditions.details = {}' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

  echo -e "${GREEN}${BOLD}Stop condition cleared${NC}"
  echo -e "Wiggum loop can continue."
}

# ─────────────────────────────────────────────────────────────────────────────
# RESET-GATE - Reset failure count for a gate
# ─────────────────────────────────────────────────────────────────────────────
reset_gate() {
  local gate="$1"

  check_status_file || return 1

  jq --arg gate "$gate" '.gate_failure_counts[$gate] = 0' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

  echo -e "${GREEN}Reset failure count for gate '$gate'${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# RESET-CHUNK - Reset iteration count for a chunk
# ─────────────────────────────────────────────────────────────────────────────
reset_chunk() {
  local chunk_id="$1"

  check_status_file || return 1

  jq --arg id "$chunk_id" '.chunk_iteration_counts[$id] = 0' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

  echo -e "${GREEN}Reset iteration count for chunk $chunk_id${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# STATUS - Show current enforcement state
# ─────────────────────────────────────────────────────────────────────────────
show_status() {
  check_status_file || return 1

  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  WIGGUM ENFORCEMENT STATUS${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""

  # Stop condition
  local stopped reason
  stopped=$(jq -r '.stop_conditions.active // false' "$STATUS_FILE")

  if [[ "$stopped" == "true" ]]; then
    reason=$(jq -r '.stop_conditions.reason' "$STATUS_FILE")
    local triggered_at
    triggered_at=$(jq -r '.stop_conditions.triggered_at' "$STATUS_FILE")
    echo -e "  ${RED}${BOLD}!! STOPPED !!${NC}"
    echo -e "  Reason: ${RED}$reason${NC}"
    echo -e "  Triggered: $triggered_at"
    echo -e "  Details:"
    jq -r '.stop_conditions.details | to_entries[] | "    \(.key): \(.value)"' "$STATUS_FILE" 2>/dev/null || true
  else
    echo -e "  ${GREEN}Status: RUNNING${NC}"
  fi

  echo ""
  echo -e "${BOLD}  Limits${NC}"
  echo -e "  Max gate failures:       $MAX_GATE_FAILURES"
  echo -e "  Max chunk iterations:    $MAX_CHUNK_ITERATIONS"

  echo ""
  echo -e "${BOLD}  Gate Failure Counts${NC}"
  local gates=("test" "lint" "typecheck" "build" "format")
  for gate in "${gates[@]}"; do
    local count
    count=$(jq -r ".gate_failure_counts.$gate // 0" "$STATUS_FILE")
    local color="$GREEN"
    [[ "$count" -gt 0 ]] && color="$YELLOW"
    [[ "$count" -ge "$MAX_GATE_FAILURES" ]] && color="$RED"
    printf "  %-12s: ${color}%d/%d${NC}\n" "$gate" "$count" "$MAX_GATE_FAILURES"
  done

  echo ""
  echo -e "${BOLD}  Chunk Iteration Counts${NC}"
  local has_chunks=false
  while IFS= read -r line; do
    has_chunks=true
    local id count
    id=$(echo "$line" | jq -r '.key')
    count=$(echo "$line" | jq -r '.value')
    local color="$GREEN"
    [[ "$count" -gt 3 ]] && color="$YELLOW"
    [[ "$count" -gt "$MAX_CHUNK_ITERATIONS" ]] && color="$RED"
    printf "  Chunk %-6s: ${color}%d/%d${NC}\n" "$id" "$count" "$MAX_CHUNK_ITERATIONS"
  done < <(jq -c '.chunk_iteration_counts | to_entries[]' "$STATUS_FILE" 2>/dev/null || true)

  [[ "$has_chunks" == false ]] && echo -e "  ${BLUE}(no chunks tracked yet)${NC}"

  echo ""
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
  check-gate)
    check_gate "${2:-}" "${3:-}"
    ;;
  check-chunk)
    check_chunk "${2:-}"
    ;;
  is-stopped)
    is_stopped
    ;;
  clear)
    clear_stop
    ;;
  reset-gate)
    reset_gate "${2:-}"
    ;;
  reset-chunk)
    reset_chunk "${2:-}"
    ;;
  status)
    show_status
    ;;
  *)
    echo "Wiggum Enforcement Script"
    echo ""
    echo "Usage: wiggum-enforce.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  check-gate <gate> <status>    Track gate result (passed/failed), check limit"
    echo "  check-chunk <chunk-id>        Increment chunk iteration, check limit"
    echo "  is-stopped                    Check if stopped (exit 0 if stopped, 1 if running)"
    echo "  clear                         Clear stop condition (interactive)"
    echo "  reset-gate <gate>             Reset failure count for a gate"
    echo "  reset-chunk <chunk-id>        Reset iteration count for a chunk"
    echo "  status                        Show current enforcement status"
    echo ""
    echo "Limits (from wiggum.config.json):"
    echo "  Max gate failures:     $MAX_GATE_FAILURES"
    echo "  Max chunk iterations:  $MAX_CHUNK_ITERATIONS"
    exit 1
    ;;
esac
