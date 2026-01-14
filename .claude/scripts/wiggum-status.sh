#!/usr/bin/env bash
#
# Wiggum Status Writer
# Updates .wiggum-status.json for the TUI dashboard
#
# Usage:
#   wiggum-status.sh init                           # Initialize status file
#   wiggum-status.sh phase <phase>                  # Set phase: plan, implement, review, complete
#   wiggum-status.sh iteration <n>                  # Set current iteration
#   wiggum-status.sh task <name> <status>           # Update current task
#   wiggum-status.sh chunk <id> <name> <status>     # Add/update chunk
#   wiggum-status.sh gate <name> <status> [output]  # Update gate result
#   wiggum-status.sh agent <name> <status>          # Update agent status
#   wiggum-status.sh commit <hash> <message>        # Record a commit
#

set -euo pipefail

STATUS_FILE=".wiggum-status.json"

# Ensure jq is available
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

# Initialize status file
init_status() {
  local start_commit
  start_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

  cat > "$STATUS_FILE" << EOF
{
  "session": {
    "start_time": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
    "start_commit": "$start_commit",
    "phase": "plan",
    "iteration": 0,
    "max_iterations": 5
  },
  "plan": {
    "approved": false,
    "summary": "",
    "must_have": [],
    "should_have": [],
    "nice_to_have": []
  },
  "current_task": {
    "name": "",
    "description": "",
    "status": "pending",
    "attempt": 0,
    "max_attempts": 3
  },
  "chunks": [],
  "gates": {
    "test": {"command": "", "status": "pending", "output": "", "attempts": 0},
    "lint": {"command": "", "status": "pending", "output": "", "attempts": 0},
    "typecheck": {"command": "", "status": "pending", "output": "", "attempts": 0},
    "build": {"command": "", "status": "pending", "output": "", "attempts": 0},
    "format": {"command": "", "status": "pending", "output": "", "attempts": 0}
  },
  "agents": [
    {"name": "researcher", "status": "idle", "last_output": "", "blockers": 0, "warnings": 0},
    {"name": "test-writer", "status": "idle", "last_output": "", "blockers": 0, "warnings": 0},
    {"name": "code-reviewer", "status": "idle", "last_output": "", "blockers": 0, "warnings": 0},
    {"name": "code-simplifier", "status": "idle", "last_output": "", "blockers": 0, "warnings": 0}
  ],
  "commits": [],
  "stats": {
    "total_iterations": 0,
    "chunks_completed": 0,
    "chunks_total": 0,
    "gates_passed": 0,
    "gates_failed": 0,
    "commits_made": 0
  }
}
EOF
  echo "Initialized $STATUS_FILE"
}

# Update phase
set_phase() {
  local phase="$1"
  jq --arg phase "$phase" '.session.phase = $phase' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Phase set to: $phase"
}

# Update iteration
set_iteration() {
  local iteration="$1"
  jq --argjson iter "$iteration" '.session.iteration = $iter | .stats.total_iterations = $iter' "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Iteration set to: $iteration"
}

# Update current task
set_task() {
  local name="$1"
  local status="$2"
  local description="${3:-}"

  jq --arg name "$name" --arg status "$status" --arg desc "$description" \
    '.current_task.name = $name | .current_task.status = $status | .current_task.description = $desc' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Task updated: $name ($status)"
}

# Add or update chunk
set_chunk() {
  local id="$1"
  local name="$2"
  local status="$3"

  # Check if chunk exists
  local exists
  exists=$(jq --argjson id "$id" '.chunks | map(select(.id == $id)) | length' "$STATUS_FILE")

  if [ "$exists" -eq 0 ]; then
    # Add new chunk
    jq --argjson id "$id" --arg name "$name" --arg status "$status" \
      '.chunks += [{"id": $id, "name": $name, "status": $status, "files": [], "iteration": 0, "gates_passed": false}] | .stats.chunks_total = (.chunks | length)' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  else
    # Update existing chunk
    jq --argjson id "$id" --arg status "$status" \
      '(.chunks[] | select(.id == $id)).status = $status' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

    # Update completed count if status is completed
    if [ "$status" = "completed" ]; then
      jq '.stats.chunks_completed = ([.chunks[] | select(.status == "completed")] | length)' \
        "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
    fi
  fi
  echo "Chunk $id updated: $name ($status)"
}

# Update gate
set_gate() {
  local gate="$1"
  local status="$2"
  local output="${3:-}"
  local cmd="${4:-}"

  jq --arg gate "$gate" --arg status "$status" --arg output "$output" --arg cmd "$cmd" \
    '.gates[$gate].status = $status | .gates[$gate].output = $output | (if $cmd != "" then .gates[$gate].command = $cmd else . end) | .gates[$gate].attempts += 1' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"

  # Update stats
  if [ "$status" = "passed" ]; then
    jq '.stats.gates_passed = ([.gates | to_entries[] | select(.value.status == "passed")] | length)' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  elif [ "$status" = "failed" ]; then
    jq '.stats.gates_failed = ([.gates | to_entries[] | select(.value.status == "failed")] | length)' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  fi

  echo "Gate $gate: $status"
}

# Update agent
set_agent() {
  local name="$1"
  local status="$2"
  local output="${3:-}"
  local blockers="${4:-0}"
  local warnings="${5:-0}"

  jq --arg name "$name" --arg status "$status" --arg output "$output" --argjson blockers "$blockers" --argjson warnings "$warnings" \
    '(.agents[] | select(.name == $name)) |= (.status = $status | .last_output = $output | .blockers = $blockers | .warnings = $warnings)' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Agent $name: $status"
}

# Record commit
add_commit() {
  local hash="$1"
  local message="$2"

  jq --arg hash "$hash" --arg msg "$message" \
    '.commits += [{"hash": $hash, "message": $msg, "time": (now | todate), "files": 0}] | .stats.commits_made = (.commits | length)' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Commit recorded: $hash"
}

# Main command dispatch
case "${1:-}" in
  init)
    init_status
    ;;
  phase)
    set_phase "${2:-plan}"
    ;;
  iteration)
    set_iteration "${2:-0}"
    ;;
  task)
    set_task "${2:-}" "${3:-pending}" "${4:-}"
    ;;
  chunk)
    set_chunk "${2:-1}" "${3:-}" "${4:-pending}"
    ;;
  gate)
    set_gate "${2:-test}" "${3:-pending}" "${4:-}" "${5:-}"
    ;;
  agent)
    set_agent "${2:-}" "${3:-idle}" "${4:-}" "${5:-0}" "${6:-0}"
    ;;
  commit)
    add_commit "${2:-}" "${3:-}"
    ;;
  *)
    echo "Usage: wiggum-status.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  init                           Initialize status file"
    echo "  phase <phase>                  Set phase: plan, implement, review, complete"
    echo "  iteration <n>                  Set current iteration"
    echo "  task <name> <status> [desc]    Update current task"
    echo "  chunk <id> <name> <status>     Add/update chunk"
    echo "  gate <name> <status> [output]  Update gate (test, lint, typecheck, build, format)"
    echo "  agent <name> <status> [output] Update agent status"
    echo "  commit <hash> <message>        Record a commit"
    exit 1
    ;;
esac
