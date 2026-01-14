package main

import (
	"encoding/json"
	"os"
	"time"
)

// WiggumStatus represents the current state of a wiggum session
type WiggumStatus struct {
	Session              SessionInfo         `json:"session"`
	Plan                 PlanInfo            `json:"plan"`
	CurrentTask          TaskInfo            `json:"current_task"`
	ActiveAgent          *ActiveAgentInfo    `json:"active_agent"`
	AgentHistory         []AgentHistoryEntry `json:"agent_history"`
	Chunks               []ChunkInfo         `json:"chunks"`
	Gates                GatesInfo           `json:"gates"`
	Limits               LimitsInfo          `json:"limits"`
	StopConditions       StopConditionsInfo  `json:"stop_conditions"`
	GateFailureCounts    GateFailureCounts   `json:"gate_failure_counts"`
	ChunkIterationCounts map[string]int      `json:"chunk_iteration_counts"`
	Agents               []AgentStatus       `json:"agents"`
	Commits              []CommitInfo        `json:"commits"`
	Stats                StatsInfo           `json:"stats"`
}

type SessionInfo struct {
	StartTime     time.Time `json:"start_time"`
	StartCommit   string    `json:"start_commit"`
	Phase         string    `json:"phase"` // plan, implement, review, complete
	Iteration     int       `json:"iteration"`
	MaxIterations int       `json:"max_iterations"`
}

type PlanInfo struct {
	Approved   bool     `json:"approved"`
	Summary    string   `json:"summary"`
	MustHave   []string `json:"must_have"`
	ShouldHave []string `json:"should_have"`
	NiceToHave []string `json:"nice_to_have"`
}

type TaskInfo struct {
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Status      string    `json:"status"` // pending, in_progress, completed, failed
	StartTime   time.Time `json:"start_time,omitempty"`
	Attempt     int       `json:"attempt"`
	MaxAttempts int       `json:"max_attempts"`
}

// ActiveAgentInfo tracks a currently running agent
type ActiveAgentInfo struct {
	Name      string    `json:"name"`
	Task      string    `json:"task"`
	StartedAt time.Time `json:"started_at"`
	Progress  string    `json:"progress"`
}

// AgentHistoryEntry records a completed agent run
type AgentHistoryEntry struct {
	Name          string    `json:"name"`
	Task          string    `json:"task"`
	StartedAt     time.Time `json:"started_at"`
	EndedAt       time.Time `json:"ended_at"`
	Status        string    `json:"status"`
	FinalProgress string    `json:"final_progress"`
}

type ChunkInfo struct {
	ID          int      `json:"id"`
	Name        string   `json:"name"`
	Status      string   `json:"status"` // pending, in_progress, completed, failed
	Files       []string `json:"files"`
	Iteration   int      `json:"iteration"`
	GatesPassed bool     `json:"gates_passed"`
}

type GatesInfo struct {
	Test      GateResult `json:"test"`
	Lint      GateResult `json:"lint"`
	TypeCheck GateResult `json:"typecheck"`
	Build     GateResult `json:"build"`
	Format    GateResult `json:"format"`
}

type GateResult struct {
	Command  string    `json:"command"`
	Status   string    `json:"status"` // pending, running, passed, failed, skipped
	Output   string    `json:"output,omitempty"`
	LastRun  time.Time `json:"last_run,omitempty"`
	Attempts int       `json:"attempts"`
}

// LimitsInfo contains enforcement limits
type LimitsInfo struct {
	MaxIterationsPerChunk int `json:"max_iterations_per_chunk"`
	MaxGateFailures       int `json:"max_gate_failures"`
}

// StopConditionsInfo tracks if a stop condition is active
type StopConditionsInfo struct {
	Active      bool                   `json:"active"`
	Reason      string                 `json:"reason"`
	TriggeredAt time.Time              `json:"triggered_at"`
	Details     map[string]interface{} `json:"details"`
}

// GateFailureCounts tracks consecutive failures per gate
type GateFailureCounts struct {
	Test      int `json:"test"`
	Lint      int `json:"lint"`
	TypeCheck int `json:"typecheck"`
	Build     int `json:"build"`
	Format    int `json:"format"`
}

type AgentStatus struct {
	Name       string    `json:"name"`   // researcher, test-writer, code-reviewer, code-simplifier
	Status     string    `json:"status"` // idle, active, done
	LastOutput string    `json:"last_output,omitempty"`
	Blockers   int       `json:"blockers"`
	Warnings   int       `json:"warnings"`
	LastRun    time.Time `json:"last_run,omitempty"`
}

type CommitInfo struct {
	Hash    string    `json:"hash"`
	Message string    `json:"message"`
	Time    time.Time `json:"time"`
	Files   int       `json:"files"`
}

type StatsInfo struct {
	TotalIterations int           `json:"total_iterations"`
	ChunksCompleted int           `json:"chunks_completed"`
	ChunksTotal     int           `json:"chunks_total"`
	GatesPassed     int           `json:"gates_passed"`
	GatesFailed     int           `json:"gates_failed"`
	CommitsMade     int           `json:"commits_made"`
	ElapsedTime     time.Duration `json:"elapsed_time"`
}

// LoadStatus reads the status from a JSON file
func LoadStatus(path string) (*WiggumStatus, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var status WiggumStatus
	if err := json.Unmarshal(data, &status); err != nil {
		return nil, err
	}

	return &status, nil
}

// NewEmptyStatus creates a default empty status
func NewEmptyStatus() *WiggumStatus {
	return &WiggumStatus{
		Session: SessionInfo{
			Phase:         "waiting",
			MaxIterations: 5,
		},
		Plan: PlanInfo{},
		CurrentTask: TaskInfo{
			Status:      "waiting",
			MaxAttempts: 3,
		},
		ActiveAgent:  nil,
		AgentHistory: []AgentHistoryEntry{},
		Chunks:       []ChunkInfo{},
		Gates: GatesInfo{
			Test:      GateResult{Status: "pending"},
			Lint:      GateResult{Status: "pending"},
			TypeCheck: GateResult{Status: "pending"},
			Build:     GateResult{Status: "pending"},
			Format:    GateResult{Status: "pending"},
		},
		Limits: LimitsInfo{
			MaxIterationsPerChunk: 5,
			MaxGateFailures:       3,
		},
		StopConditions: StopConditionsInfo{
			Active:  false,
			Details: make(map[string]interface{}),
		},
		GateFailureCounts:    GateFailureCounts{},
		ChunkIterationCounts: make(map[string]int),
		Agents:               []AgentStatus{},
		Commits:              []CommitInfo{},
		Stats:                StatsInfo{},
	}
}
