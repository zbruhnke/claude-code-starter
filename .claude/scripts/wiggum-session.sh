#!/usr/bin/env bash
#
# Wiggum Session Manager
# Manages session lifecycle, persistence, and recovery
#
# Usage:
#   wiggum-session.sh start [spec]         # Start new session
#   wiggum-session.sh checkpoint           # Save current checkpoint
#   wiggum-session.sh resume               # Output context for resuming
#   wiggum-session.sh status               # Show session status
#   wiggum-session.sh end                  # End session (validation must pass)
#   wiggum-session.sh abort                # Force end without validation
#
# Files:
#   .wiggum-session    - Session marker/state file (JSON)
#   .wiggum-spec.md    - Saved spec for resumption
#   .wiggum-status.json - Runtime status (TUI dashboard)
#

set -euo pipefail

SESSION_FILE=".wiggum-session"
SPEC_FILE=".wiggum-spec.md"
STATUS_FILE=".wiggum-status.json"
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

# Generate a UUID (cross-platform)
generate_uuid() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  elif [[ -f /proc/sys/kernel/random/uuid ]]; then
    cat /proc/sys/kernel/random/uuid
  else
    # Fallback: timestamp + random
    echo "$(date +%s)-$RANDOM-$RANDOM"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# START - Initialize a new session
# ─────────────────────────────────────────────────────────────────────────────
start_session() {
  local spec="${1:-}"

  # Check if session already exists
  if [[ -f "$SESSION_FILE" ]]; then
    echo -e "${YELLOW}Session already exists.${NC}"
    echo -e "Run ${BLUE}wiggum-session.sh resume${NC} to continue, or"
    echo -e "Run ${BLUE}wiggum-session.sh abort${NC} to start fresh."
    return 1
  fi

  # Save spec for resumption (if provided)
  if [[ -n "$spec" ]]; then
    echo "$spec" > "$SPEC_FILE"
    echo -e "${GREEN}Spec saved to $SPEC_FILE${NC}"
  fi

  local spec_hash=""
  if [[ -f "$SPEC_FILE" ]]; then
    if command -v sha256sum &>/dev/null; then
      spec_hash=$(sha256sum "$SPEC_FILE" | cut -d' ' -f1)
    elif command -v shasum &>/dev/null; then
      spec_hash=$(shasum -a 256 "$SPEC_FILE" | cut -d' ' -f1)
    fi
  fi

  local session_id
  session_id=$(generate_uuid)

  local start_commit
  start_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

  # Create session file with full state
  jq -n \
    --arg id "$session_id" \
    --arg commit "$start_commit" \
    --arg hash "$spec_hash" \
    '{
      session_id: $id,
      started_at: (now | todate),
      starting_commit: $commit,
      spec_hash: $hash,
      spec_file: ".wiggum-spec.md",
      plan_approved: false,
      plan_file: null,
      last_checkpoint: (now | todate),
      last_chunk_id: 0,
      last_phase: "plan",
      checkpoints: []
    }' > "$SESSION_FILE"

  echo -e "${GREEN}${BOLD}Session started: $session_id${NC}"
  echo -e "Starting commit: $start_commit"
  echo ""
  echo -e "Session file: ${BLUE}$SESSION_FILE${NC}"
  echo -e "Status file:  ${BLUE}$STATUS_FILE${NC}"
  [[ -f "$SPEC_FILE" ]] && echo -e "Spec file:    ${BLUE}$SPEC_FILE${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# CHECKPOINT - Save current state
# ─────────────────────────────────────────────────────────────────────────────
save_checkpoint() {
  if [[ ! -f "$SESSION_FILE" ]]; then
    echo -e "${RED}No active session${NC}" >&2
    return 1
  fi

  # Get current state from status file
  local phase="unknown"
  local chunk_id=0
  local iteration=0

  if [[ -f "$STATUS_FILE" ]]; then
    phase=$(jq -r '.session.phase // "unknown"' "$STATUS_FILE")
    chunk_id=$(jq -r '.chunks | map(select(.status == "in_progress")) | .[0].id // 0' "$STATUS_FILE")
    iteration=$(jq -r '.session.iteration // 0' "$STATUS_FILE")
  fi

  # Update session file with checkpoint
  local checkpoint
  checkpoint=$(jq -n \
    --arg phase "$phase" \
    --argjson chunk "$chunk_id" \
    --argjson iter "$iteration" \
    '{
      time: (now | todate),
      phase: $phase,
      chunk_id: $chunk,
      iteration: $iter
    }')

  jq --argjson cp "$checkpoint" --arg phase "$phase" --argjson chunk "$chunk_id" \
    '.last_checkpoint = (now | todate) |
     .last_phase = $phase |
     .last_chunk_id = $chunk |
     .checkpoints += [$cp]' \
    "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"

  echo -e "${GREEN}Checkpoint saved${NC}"
  echo -e "  Phase: $phase"
  echo -e "  Chunk: $chunk_id"
  echo -e "  Iteration: $iteration"
}

# ─────────────────────────────────────────────────────────────────────────────
# RESUME - Output context for resuming interrupted session
# ─────────────────────────────────────────────────────────────────────────────
resume_session() {
  if [[ ! -f "$SESSION_FILE" ]]; then
    echo -e "${RED}No session to resume${NC}" >&2
    return 1
  fi

  local session_id last_phase last_chunk_id spec_hash started_at
  session_id=$(jq -r '.session_id' "$SESSION_FILE")
  last_phase=$(jq -r '.last_phase' "$SESSION_FILE")
  last_chunk_id=$(jq -r '.last_chunk_id' "$SESSION_FILE")
  spec_hash=$(jq -r '.spec_hash' "$SESSION_FILE")
  started_at=$(jq -r '.started_at' "$SESSION_FILE")

  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  WIGGUM SESSION RESUME${NC}"
  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "Session ID:   ${BLUE}$session_id${NC}"
  echo -e "Started:      $started_at"
  echo -e "Last Phase:   ${YELLOW}$last_phase${NC}"
  echo -e "Last Chunk:   $last_chunk_id"
  echo ""

  # Verify spec hasn't changed
  if [[ -f "$SPEC_FILE" ]] && [[ -n "$spec_hash" ]]; then
    local current_hash=""
    if command -v sha256sum &>/dev/null; then
      current_hash=$(sha256sum "$SPEC_FILE" | cut -d' ' -f1)
    elif command -v shasum &>/dev/null; then
      current_hash=$(shasum -a 256 "$SPEC_FILE" | cut -d' ' -f1)
    fi

    if [[ "$current_hash" != "$spec_hash" ]]; then
      echo -e "${YELLOW}WARNING: Spec file has changed since session started${NC}"
    fi
  fi

  echo -e "${BOLD}─── Original Spec ───${NC}"
  if [[ -f "$SPEC_FILE" ]]; then
    cat "$SPEC_FILE"
  else
    echo -e "${YELLOW}(Spec file not found)${NC}"
  fi
  echo ""

  echo -e "${BOLD}─── Current Status ───${NC}"
  if [[ -f "$STATUS_FILE" ]]; then
    echo -e "Phase:       $(jq -r '.session.phase // "unknown"' "$STATUS_FILE")"
    echo -e "Iteration:   $(jq -r '.session.iteration // 0' "$STATUS_FILE")"
    echo -e "Chunks:      $(jq -r '.stats.chunks_completed // 0' "$STATUS_FILE")/$(jq -r '.stats.chunks_total // 0' "$STATUS_FILE")"
    echo -e "Commits:     $(jq -r '.stats.commits_made // 0' "$STATUS_FILE")"

    local stopped
    stopped=$(jq -r '.stop_conditions.active // false' "$STATUS_FILE")
    if [[ "$stopped" == "true" ]]; then
      echo -e ""
      echo -e "${RED}STOP CONDITION ACTIVE${NC}"
      echo -e "Reason: $(jq -r '.stop_conditions.reason' "$STATUS_FILE")"
    fi
  else
    echo -e "${YELLOW}(Status file not found - may need to reinitialize)${NC}"
  fi
  echo ""

  echo -e "${BOLD}─── Recent Git Activity ───${NC}"
  git log --oneline -5 2>/dev/null || echo "(no git history)"
  echo ""

  echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${GREEN}Continue the wiggum loop from phase: ${BOLD}$last_phase${NC}"
  if [[ "$last_phase" == "plan" ]]; then
    echo -e "The plan was not yet approved. Start with planning."
  elif [[ "$last_phase" == "implement" ]]; then
    echo -e "Continue implementing from chunk $last_chunk_id."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# STATUS - Show current session status
# ─────────────────────────────────────────────────────────────────────────────
show_status() {
  if [[ ! -f "$SESSION_FILE" ]]; then
    echo -e "${YELLOW}No active session${NC}"
    return 0
  fi

  echo -e "${BOLD}Session Status${NC}"
  echo ""
  jq '.' "$SESSION_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# END - End session after validation passes
# ─────────────────────────────────────────────────────────────────────────────
end_session() {
  if [[ ! -f "$SESSION_FILE" ]]; then
    echo -e "${YELLOW}No active session${NC}"
    return 0
  fi

  echo -e "${BOLD}Running validation before ending session...${NC}"
  echo ""

  # Run validation
  if ! "$SCRIPT_DIR/wiggum-validate.sh"; then
    echo ""
    echo -e "${RED}Cannot end session - validation failed${NC}"
    echo -e "Fix the issues above and run validation again."
    return 1
  fi

  echo ""
  echo -e "${GREEN}Validation passed - ending session${NC}"
  cleanup_session
}

# ─────────────────────────────────────────────────────────────────────────────
# ABORT - Force end session without validation
# ─────────────────────────────────────────────────────────────────────────────
abort_session() {
  if [[ ! -f "$SESSION_FILE" ]]; then
    echo -e "${YELLOW}No active session${NC}"
    return 0
  fi

  echo -e "${YELLOW}Aborting session...${NC}"

  # Archive the session file for debugging
  local archive_name=".wiggum-session.aborted.$(date +%Y%m%d-%H%M%S)"
  cp "$SESSION_FILE" "$archive_name" 2>/dev/null || true
  echo -e "Session archived to: $archive_name"

  cleanup_session
  echo -e "${GREEN}Session aborted${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# CLEANUP - Remove session files
# ─────────────────────────────────────────────────────────────────────────────
cleanup_session() {
  rm -f "$SESSION_FILE" "$SPEC_FILE"
  # Keep status file for reference
  echo -e "Session files removed"
}

# ─────────────────────────────────────────────────────────────────────────────
# APPROVE-PLAN - Mark plan as approved
# ─────────────────────────────────────────────────────────────────────────────
approve_plan() {
  if [[ ! -f "$SESSION_FILE" ]]; then
    echo -e "${RED}No active session${NC}" >&2
    return 1
  fi

  jq '.plan_approved = true | .last_phase = "implement"' \
    "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"

  # Also update status file
  if [[ -f "$STATUS_FILE" ]]; then
    jq '.plan.approved = true | .session.phase = "implement"' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  fi

  echo -e "${GREEN}Plan approved - ready to implement${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
case "${1:-}" in
  start)
    shift
    start_session "$*"
    ;;
  checkpoint)
    save_checkpoint
    ;;
  resume)
    resume_session
    ;;
  status)
    show_status
    ;;
  end)
    end_session
    ;;
  abort)
    abort_session
    ;;
  approve-plan)
    approve_plan
    ;;
  *)
    echo "Wiggum Session Manager"
    echo ""
    echo "Usage: wiggum-session.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  start [spec]      Start new session (optionally with spec text)"
    echo "  checkpoint        Save current state checkpoint"
    echo "  resume            Output context for resuming interrupted session"
    echo "  status            Show current session status"
    echo "  end               End session (validation must pass)"
    echo "  abort             Force end session without validation"
    echo "  approve-plan      Mark plan as approved"
    echo ""
    echo "Files:"
    echo "  $SESSION_FILE   Session state and checkpoints"
    echo "  $SPEC_FILE      Saved spec for resumption"
    echo "  $STATUS_FILE    Runtime status (TUI dashboard)"
    exit 1
    ;;
esac
