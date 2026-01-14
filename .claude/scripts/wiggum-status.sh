#!/usr/bin/env bash
#
# Wiggum Status Writer
# Updates .wiggum-status.json for the TUI dashboard
#
# Usage:
#   wiggum-status.sh init                              # Initialize status file
#   wiggum-status.sh phase <phase>                     # Set phase: plan, implement, review, complete
#   wiggum-status.sh iteration <n>                     # Set current iteration
#   wiggum-status.sh task <name> <status> [desc]       # Update current task
#   wiggum-status.sh chunk <id> <name> <status>        # Add/update chunk
#   wiggum-status.sh gate <name> <status> [output]     # Update gate result
#   wiggum-status.sh agent <name> <status> [output]    # Update agent status (idle/active/done)
#   wiggum-status.sh commit <hash> <message>           # Record a commit
#
# NEW - Active Agent Tracking:
#   wiggum-status.sh agent-start <name> <task>         # Start tracking an active agent
#   wiggum-status.sh agent-progress <message>          # Update progress of active agent
#   wiggum-status.sh agent-end <status>                # End active agent, move to history
#
# NEW - Plan Management:
#   wiggum-status.sh plan-approve [summary]            # Mark plan as approved
#   wiggum-status.sh plan-requirement <type> <req>     # Add requirement (must_have/should_have/nice_to_have)
#

set -euo pipefail

STATUS_FILE=".wiggum-status.json"
CONFIG_FILE="wiggum.config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure jq is available
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

# Load limits from config or use defaults
get_limit() {
  local name="$1"
  local default="$2"
  if [[ -f "$CONFIG_FILE" ]]; then
    local val
    val=$(jq -r ".limits.$name // empty" "$CONFIG_FILE" 2>/dev/null)
    [[ -n "$val" ]] && echo "$val" || echo "$default"
  else
    echo "$default"
  fi
}

# Load command from config
get_command() {
  local gate="$1"
  if [[ -f "$CONFIG_FILE" ]]; then
    jq -r ".commands.$gate.command // empty" "$CONFIG_FILE" 2>/dev/null
  else
    echo ""
  fi
}

# Initialize status file
init_status() {
  local start_commit
  start_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")

  # Load limits from config
  local max_iter max_fail
  max_iter=$(get_limit "max_iterations_per_chunk" 5)
  max_fail=$(get_limit "max_gate_failures" 3)

  # Load commands from config
  local test_cmd lint_cmd typecheck_cmd build_cmd format_cmd
  test_cmd=$(get_command "test")
  lint_cmd=$(get_command "lint")
  typecheck_cmd=$(get_command "typecheck")
  build_cmd=$(get_command "build")
  format_cmd=$(get_command "format")

  cat > "$STATUS_FILE" << EOF
{
  "session": {
    "start_time": "$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')",
    "start_commit": "$start_commit",
    "phase": "plan",
    "iteration": 0,
    "max_iterations": $max_iter
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
  "active_agent": null,
  "agent_history": [],
  "chunks": [],
  "gates": {
    "test": {"command": "$test_cmd", "status": "pending", "output": "", "attempts": 0},
    "lint": {"command": "$lint_cmd", "status": "pending", "output": "", "attempts": 0},
    "typecheck": {"command": "$typecheck_cmd", "status": "pending", "output": "", "attempts": 0},
    "build": {"command": "$build_cmd", "status": "pending", "output": "", "attempts": 0},
    "format": {"command": "$format_cmd", "status": "pending", "output": "", "attempts": 0}
  },
  "limits": {
    "max_iterations_per_chunk": $max_iter,
    "max_gate_failures": $max_fail
  },
  "stop_conditions": {
    "active": false,
    "reason": null,
    "triggered_at": null,
    "details": {}
  },
  "gate_failure_counts": {
    "test": 0,
    "lint": 0,
    "typecheck": 0,
    "build": 0,
    "format": 0
  },
  "chunk_iteration_counts": {},
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
    # Reset failure count on success
    jq --arg gate "$gate" '.gate_failure_counts[$gate] = 0' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  elif [ "$status" = "failed" ]; then
    jq '.stats.gates_failed = ([.gates | to_entries[] | select(.value.status == "failed")] | length)' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
    # Increment failure count
    jq --arg gate "$gate" '.gate_failure_counts[$gate] += 1' \
      "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  fi

  echo "Gate $gate: $status"
}

# Update agent (legacy - for backward compatibility)
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

# Start active agent tracking
start_active_agent() {
  local name="$1"
  local task="$2"

  jq --arg name "$name" --arg task "$task" \
    '.active_agent = {
      "name": $name,
      "task": $task,
      "started_at": (now | todate),
      "progress": "Starting..."
    }' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Active agent started: $name - $task"
}

# Update active agent progress
update_agent_progress() {
  local message="$1"

  jq --arg msg "$message" \
    'if .active_agent then .active_agent.progress = $msg else . end' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Agent progress: $message"
}

# End active agent and move to history
end_active_agent() {
  local status="$1"

  # Calculate duration and move to history
  jq --arg status "$status" \
    'if .active_agent then
      .agent_history += [{
        "name": .active_agent.name,
        "task": .active_agent.task,
        "started_at": .active_agent.started_at,
        "ended_at": (now | todate),
        "status": $status,
        "final_progress": .active_agent.progress
      }] |
      .active_agent = null
    else . end' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Active agent ended: $status"
}

# Approve plan
approve_plan() {
  local summary="${1:-}"

  jq --arg summary "$summary" \
    '.plan.approved = true | .plan.summary = $summary' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Plan approved"
}

# Add requirement
add_requirement() {
  local type="$1"
  local requirement="$2"

  jq --arg type "$type" --arg req "$requirement" \
    '.plan[$type] += [$req]' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Added $type requirement: $requirement"
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

# Trigger stop condition
trigger_stop() {
  local reason="$1"
  local details="$2"

  jq --arg reason "$reason" --argjson details "$details" \
    '.stop_conditions.active = true |
     .stop_conditions.reason = $reason |
     .stop_conditions.triggered_at = (now | todate) |
     .stop_conditions.details = $details' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "STOP CONDITION TRIGGERED: $reason"
}

# Clear stop condition
clear_stop() {
  jq '.stop_conditions.active = false |
      .stop_conditions.reason = null |
      .stop_conditions.triggered_at = null |
      .stop_conditions.details = {}' \
    "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
  echo "Stop condition cleared"
}

# Check if stopped
is_stopped() {
  local stopped
  stopped=$(jq -r '.stop_conditions.active // false' "$STATUS_FILE")
  [[ "$stopped" == "true" ]] && return 0 || return 1
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
  agent-start)
    start_active_agent "${2:-}" "${3:-}"
    ;;
  agent-progress)
    update_agent_progress "${2:-}"
    ;;
  agent-end)
    end_active_agent "${2:-completed}"
    ;;
  plan-approve)
    approve_plan "${2:-}"
    ;;
  plan-requirement)
    add_requirement "${2:-must_have}" "${3:-}"
    ;;
  commit)
    add_commit "${2:-}" "${3:-}"
    ;;
  stop)
    trigger_stop "${2:-manual}" "${3:-{}}"
    ;;
  clear-stop)
    clear_stop
    ;;
  is-stopped)
    is_stopped && echo "STOPPED" || echo "RUNNING"
    ;;
  *)
    echo "Wiggum Status Writer"
    echo ""
    echo "Usage: wiggum-status.sh <command> [args]"
    echo ""
    echo "Session Management:"
    echo "  init                              Initialize status file"
    echo "  phase <phase>                     Set phase: plan, implement, review, complete"
    echo "  iteration <n>                     Set current iteration"
    echo ""
    echo "Task & Chunk Tracking:"
    echo "  task <name> <status> [desc]       Update current task"
    echo "  chunk <id> <name> <status>        Add/update chunk"
    echo ""
    echo "Gate Management:"
    echo "  gate <name> <status> [output]     Update gate (test, lint, typecheck, build, format)"
    echo ""
    echo "Agent Tracking (Legacy):"
    echo "  agent <name> <status> [output]    Update agent status"
    echo ""
    echo "Active Agent Tracking (New):"
    echo "  agent-start <name> <task>         Start tracking an active agent"
    echo "  agent-progress <message>          Update progress of active agent"
    echo "  agent-end <status>                End active agent (completed/failed/cancelled)"
    echo ""
    echo "Plan Management:"
    echo "  plan-approve [summary]            Mark plan as approved"
    echo "  plan-requirement <type> <req>     Add requirement (must_have/should_have/nice_to_have)"
    echo ""
    echo "Commits:"
    echo "  commit <hash> <message>           Record a commit"
    echo ""
    echo "Stop Conditions:"
    echo "  stop <reason> [details-json]      Trigger a stop condition"
    echo "  clear-stop                        Clear stop condition"
    echo "  is-stopped                        Check if stopped (exit 0 if stopped)"
    exit 1
    ;;
esac
