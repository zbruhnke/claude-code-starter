package main

import (
	"strings"
	"testing"
	"time"
)

// Helper to create a model with default width/height for testing
func newTestModel() model {
	return model{
		status: NewEmptyStatus(),
		width:  100,
		height: 40,
		frame:  0,
	}
}

// Helper to create a model with specific phase
func newTestModelWithPhase(phase string) model {
	m := newTestModel()
	m.status.Session.Phase = phase
	return m
}

// =============================================================================
// Phase Dispatch Tests - View()
// =============================================================================

func TestView_ZeroWidth_ReturnsInitializing(t *testing.T) {
	m := model{
		status: NewEmptyStatus(),
		width:  0,
		height: 0,
	}

	result := m.View()

	if !strings.Contains(result, "INITIALIZING") {
		t.Errorf("expected view to contain 'INITIALIZING' when width is 0, got: %q", result)
	}
}

func TestView_StandbyPhase_ReturnsStandbyView(t *testing.T) {
	m := newTestModelWithPhase("")

	result := m.View()

	// Standby view should show awaiting message
	if !strings.Contains(result, "Awaiting session") {
		t.Errorf("standby phase should contain 'Awaiting session', got: %q", result)
	}
	if !strings.Contains(result, "Standby") {
		t.Errorf("standby phase should contain 'Standby' in footer, got: %q", result)
	}
}

func TestView_WaitingPhase_ReturnsStandbyView(t *testing.T) {
	m := newTestModelWithPhase("waiting")

	result := m.View()

	// "waiting" should also go to standby
	if !strings.Contains(result, "Awaiting session") {
		t.Errorf("waiting phase should show standby view with 'Awaiting session', got: %q", result)
	}
}

func TestView_PlanPhase_ReturnsPlanView(t *testing.T) {
	m := newTestModelWithPhase("plan")

	result := m.View()

	if !strings.Contains(result, "PLANNING") {
		t.Errorf("plan phase should contain 'PLANNING' in header, got: %q", result)
	}
	if !strings.Contains(result, "Planning") {
		t.Errorf("plan phase should contain 'Planning' status in footer, got: %q", result)
	}
}

func TestView_ImplementPhase_ReturnsImplementView(t *testing.T) {
	m := newTestModelWithPhase("implement")

	result := m.View()

	if !strings.Contains(result, "IMPLEMENTING") {
		t.Errorf("implement phase should contain 'IMPLEMENTING' in header, got: %q", result)
	}
	if !strings.Contains(result, "Implementing") {
		t.Errorf("implement phase should contain 'Implementing' status in footer, got: %q", result)
	}
}

func TestView_ReviewPhase_ReturnsReviewView(t *testing.T) {
	m := newTestModelWithPhase("review")

	result := m.View()

	if !strings.Contains(result, "FINAL REVIEW") {
		t.Errorf("review phase should contain 'FINAL REVIEW' in header, got: %q", result)
	}
	if !strings.Contains(result, "Reviewing") {
		t.Errorf("review phase should contain 'Reviewing' status in footer, got: %q", result)
	}
}

func TestView_CompletePhase_ReturnsCompleteView(t *testing.T) {
	m := newTestModelWithPhase("complete")

	result := m.View()

	if !strings.Contains(result, "COMPLETE") {
		t.Errorf("complete phase should contain 'COMPLETE' in header, got: %q", result)
	}
	if !strings.Contains(result, "Session completed successfully") {
		t.Errorf("complete phase should contain success message, got: %q", result)
	}
}

func TestView_ErrorWithNoPhase_DefaultsToStandby(t *testing.T) {
	m := newTestModel()
	m.status.Session.Phase = ""
	m.err = &testError{msg: "test error"}

	result := m.View()

	// Should show standby view with error
	if !strings.Contains(result, "Awaiting session") {
		t.Errorf("error with no phase should show standby view, got: %q", result)
	}
}

// =============================================================================
// Standby Phase Renderer Tests
// =============================================================================

func TestRenderStandbyPhase_ShowsAwaitingMessage(t *testing.T) {
	m := newTestModel()
	m.status.Session.Phase = ""

	result := m.renderStandbyPhase()

	if !strings.Contains(result, "Awaiting session") {
		t.Errorf("standby phase should show 'Awaiting session', got: %q", result)
	}
}

func TestRenderStandbyPhase_ShowsHelpMessage(t *testing.T) {
	m := newTestModel()
	m.status.Session.Phase = ""

	result := m.renderStandbyPhase()

	if !strings.Contains(result, "/wiggum") {
		t.Errorf("standby phase should show help about /wiggum command, got: %q", result)
	}
}

func TestRenderStandbyPhase_ShowsErrorWhenPresent(t *testing.T) {
	m := newTestModel()
	m.err = &testError{msg: "file not found"}

	result := m.renderStandbyPhase()

	if !strings.Contains(result, "file not found") {
		t.Errorf("standby phase should show error message when present, got: %q", result)
	}
}

// =============================================================================
// Plan Phase Renderer Tests
// =============================================================================

func TestRenderPlanPhase_ShowsSessionSection(t *testing.T) {
	m := newTestModelWithPhase("plan")
	m.status.Session.StartTime = time.Now().Add(-5 * time.Minute)

	result := m.renderPlanPhase()

	if !strings.Contains(result, "Session") {
		t.Errorf("plan phase should show Session section, got: %q", result)
	}
}

func TestRenderPlanPhase_ShowsActiveAgent_WhenPresent(t *testing.T) {
	m := newTestModelWithPhase("plan")
	m.status.ActiveAgent = &ActiveAgentInfo{
		Name: "researcher",
		Task: "Analyzing codebase",
	}

	result := m.renderPlanPhase()

	if !strings.Contains(result, "Active Agent") {
		t.Errorf("plan phase should show Active Agent when present, got: %q", result)
	}
	if !strings.Contains(result, "researcher") {
		t.Errorf("plan phase should show agent name, got: %q", result)
	}
}

func TestRenderPlanPhase_HidesActiveAgent_WhenNil(t *testing.T) {
	m := newTestModelWithPhase("plan")
	m.status.ActiveAgent = nil

	result := m.renderPlanPhase()

	// Should not have "Active Agent" header when no agent
	// Note: The section header won't appear if ActiveAgent is nil
	lines := strings.Split(result, "\n")
	activeAgentHeaderFound := false
	for _, line := range lines {
		if strings.Contains(line, "Active Agent") {
			activeAgentHeaderFound = true
			break
		}
	}
	if activeAgentHeaderFound {
		t.Errorf("plan phase should not show Active Agent header when no agent running")
	}
}

func TestRenderPlanPhase_ShowsCurrentTask_WhenPresent(t *testing.T) {
	m := newTestModelWithPhase("plan")
	m.status.CurrentTask = TaskInfo{
		Name:        "Parse requirements",
		Description: "Extracting must-have features",
		Status:      "in_progress",
	}

	result := m.renderPlanPhase()

	if !strings.Contains(result, "Current Task") {
		t.Errorf("plan phase should show Current Task when present, got: %q", result)
	}
	if !strings.Contains(result, "Parse requirements") {
		t.Errorf("plan phase should show task name, got: %q", result)
	}
}

func TestRenderPlanPhase_ShowsRequirements_WhenPopulated(t *testing.T) {
	m := newTestModelWithPhase("plan")
	m.status.Plan.MustHave = []string{"Feature A", "Feature B"}
	m.status.Plan.ShouldHave = []string{"Nice feature C"}

	result := m.renderPlanPhase()

	if !strings.Contains(result, "Requirements") {
		t.Errorf("plan phase should show Requirements section, got: %q", result)
	}
	if !strings.Contains(result, "Feature A") {
		t.Errorf("plan phase should show must-have requirements, got: %q", result)
	}
}

func TestRenderPlanPhase_HidesChunks(t *testing.T) {
	m := newTestModelWithPhase("plan")
	m.status.Chunks = []ChunkInfo{
		{ID: 1, Name: "Chunk 1", Status: "pending"},
	}

	result := m.renderPlanPhase()

	// Plan phase should NOT show Chunks section (that's for implement)
	if strings.Contains(result, "Chunks") {
		t.Errorf("plan phase should not show Chunks section, got: %q", result)
	}
}

// =============================================================================
// Implement Phase Renderer Tests
// =============================================================================

func TestRenderImplementPhase_ShowsTwoColumnLayout(t *testing.T) {
	m := newTestModelWithPhase("implement")

	result := m.renderImplementPhase()

	// Should have Gates section (right column)
	if !strings.Contains(result, "Gates") {
		t.Errorf("implement phase should show Gates section, got: %q", result)
	}
	// Should have Session section (left column)
	if !strings.Contains(result, "Session") {
		t.Errorf("implement phase should show Session section, got: %q", result)
	}
}

func TestRenderImplementPhase_ShowsChunks_WhenPresent(t *testing.T) {
	m := newTestModelWithPhase("implement")
	m.status.Chunks = []ChunkInfo{
		{ID: 1, Name: "Setup module", Status: "completed"},
		{ID: 2, Name: "Core logic", Status: "in_progress"},
	}

	result := m.renderImplementPhase()

	if !strings.Contains(result, "Chunks") {
		t.Errorf("implement phase should show Chunks section when chunks exist, got: %q", result)
	}
}

func TestRenderImplementPhase_ShowsCommits_WhenPresent(t *testing.T) {
	m := newTestModelWithPhase("implement")
	m.status.Commits = []CommitInfo{
		{Hash: "abc1234", Message: "feat: add feature"},
	}

	result := m.renderImplementPhase()

	if !strings.Contains(result, "Commits") {
		t.Errorf("implement phase should show Commits section when commits exist, got: %q", result)
	}
}

func TestRenderImplementPhase_ShowsAgents(t *testing.T) {
	m := newTestModelWithPhase("implement")

	result := m.renderImplementPhase()

	if !strings.Contains(result, "Agents") {
		t.Errorf("implement phase should show Agents section, got: %q", result)
	}
}

// =============================================================================
// Review Phase Renderer Tests
// =============================================================================

func TestRenderReviewPhase_ShowsGatesProminent(t *testing.T) {
	m := newTestModelWithPhase("review")

	result := m.renderReviewPhase()

	// Gates should be at the top
	gatesIndex := strings.Index(result, "GATES")
	agentsIndex := strings.Index(result, "Agent Status")

	if gatesIndex == -1 {
		t.Errorf("review phase should show GATES section, got: %q", result)
	}
	if agentsIndex != -1 && gatesIndex > agentsIndex {
		t.Errorf("review phase should show GATES before Agent Status, gates at %d, agents at %d", gatesIndex, agentsIndex)
	}
}

func TestRenderReviewPhase_ShowsAllGatesPassed_WhenTrue(t *testing.T) {
	m := newTestModelWithPhase("review")
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "passed"}

	result := m.renderReviewPhase()

	if !strings.Contains(result, "ALL PASSED") {
		t.Errorf("review phase should show 'ALL PASSED' when all gates pass, got: %q", result)
	}
}

func TestRenderReviewPhase_ShowsAgentStatus(t *testing.T) {
	m := newTestModelWithPhase("review")
	m.status.Agents = []AgentStatus{
		{Name: "code-reviewer", Status: "done"},
	}

	result := m.renderReviewPhase()

	if !strings.Contains(result, "Agent Status") {
		t.Errorf("review phase should show Agent Status section, got: %q", result)
	}
}

func TestRenderReviewPhase_ShowsSessionSummary(t *testing.T) {
	m := newTestModelWithPhase("review")

	result := m.renderReviewPhase()

	if !strings.Contains(result, "Session Summary") {
		t.Errorf("review phase should show Session Summary section, got: %q", result)
	}
}

func TestRenderReviewPhase_ShowsHint(t *testing.T) {
	m := newTestModelWithPhase("review")

	result := m.renderReviewPhase()

	if !strings.Contains(result, "All gates must show") {
		t.Errorf("review phase should show hint about gates, got: %q", result)
	}
}

// =============================================================================
// Complete Phase Renderer Tests
// =============================================================================

func TestRenderCompletePhase_ShowsSuccessMessage(t *testing.T) {
	m := newTestModelWithPhase("complete")

	result := m.renderCompletePhase()

	if !strings.Contains(result, "Session completed successfully") {
		t.Errorf("complete phase should show success message, got: %q", result)
	}
}

func TestRenderCompletePhase_ShowsFinalStats(t *testing.T) {
	m := newTestModelWithPhase("complete")
	m.status.Stats.ChunksCompleted = 5
	m.status.Stats.ChunksTotal = 5
	m.status.Stats.CommitsMade = 3

	result := m.renderCompletePhase()

	if !strings.Contains(result, "Final Stats") {
		t.Errorf("complete phase should show Final Stats section, got: %q", result)
	}
}

func TestRenderCompletePhase_ShowsCommits_WhenPresent(t *testing.T) {
	m := newTestModelWithPhase("complete")
	m.status.Commits = []CommitInfo{
		{Hash: "abc1234", Message: "feat: add feature"},
		{Hash: "def5678", Message: "fix: resolve bug"},
	}

	result := m.renderCompletePhase()

	if !strings.Contains(result, "Commits Made") {
		t.Errorf("complete phase should show Commits Made section when commits exist, got: %q", result)
	}
}

func TestRenderCompletePhase_HidesCommits_WhenEmpty(t *testing.T) {
	m := newTestModelWithPhase("complete")
	m.status.Commits = []CommitInfo{}

	result := m.renderCompletePhase()

	// Should not show "Commits Made" header when no commits
	if strings.Contains(result, "Commits Made") {
		t.Errorf("complete phase should not show Commits Made section when no commits, got: %q", result)
	}
}

func TestRenderCompletePhase_ShowsGatesSummary(t *testing.T) {
	m := newTestModelWithPhase("complete")

	result := m.renderCompletePhase()

	if !strings.Contains(result, "Gates (All Passed)") {
		t.Errorf("complete phase should show Gates summary section, got: %q", result)
	}
}

// =============================================================================
// Common Header/Footer Tests
// =============================================================================

func TestRenderCommonHeader_ShowsPhaseTitle(t *testing.T) {
	m := newTestModel()

	result := m.renderCommonHeader("TEST TITLE")

	if !strings.Contains(result, "TEST TITLE") {
		t.Errorf("common header should contain phase title, got: %q", result)
	}
}

func TestRenderCommonHeader_ShowsTimestamp(t *testing.T) {
	m := newTestModel()

	result := m.renderCommonHeader("TEST")

	// Should contain time format HH:MM:SS
	if !strings.Contains(result, ":") {
		t.Errorf("common header should contain timestamp, got: %q", result)
	}
}

func TestRenderCommonHeader_ShowsStopBanner_WhenActive(t *testing.T) {
	m := newTestModel()
	m.status.StopConditions.Active = true
	m.status.StopConditions.Reason = "gate_failure"

	result := m.renderCommonHeader("TEST")

	if !strings.Contains(result, "STOPPED") {
		t.Errorf("common header should show stop banner when active, got: %q", result)
	}
}

func TestRenderCommonHeader_HidesStopBanner_WhenInactive(t *testing.T) {
	m := newTestModel()
	m.status.StopConditions.Active = false

	result := m.renderCommonHeader("TEST")

	if strings.Contains(result, "STOPPED") {
		t.Errorf("common header should not show stop banner when inactive, got: %q", result)
	}
}

func TestRenderCommonFooter_ShowsQuitAndRefreshHints(t *testing.T) {
	m := newTestModel()

	result := m.renderCommonFooter("", "Status", dimStyle)

	if !strings.Contains(result, "[Q] Quit") {
		t.Errorf("common footer should show quit hint, got: %q", result)
	}
	if !strings.Contains(result, "[R] Refresh") {
		t.Errorf("common footer should show refresh hint, got: %q", result)
	}
}

func TestRenderCommonFooter_ShowsCustomHint(t *testing.T) {
	m := newTestModel()

	result := m.renderCommonFooter("Watch gates", "Status", dimStyle)

	if !strings.Contains(result, "Watch gates") {
		t.Errorf("common footer should show custom hint, got: %q", result)
	}
}

func TestRenderCommonFooter_ShowsStatus(t *testing.T) {
	m := newTestModel()

	result := m.renderCommonFooter("", "Test Status", dimStyle)

	if !strings.Contains(result, "Test Status") {
		t.Errorf("common footer should show status, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderMinimalSessionInfo
// =============================================================================

func TestRenderMinimalSessionInfo_ShowsElapsed(t *testing.T) {
	m := newTestModel()
	m.status.Session.StartTime = time.Now().Add(-10 * time.Minute)

	result := m.renderMinimalSessionInfo()

	if !strings.Contains(result, "ELAPSED") {
		t.Errorf("minimal session info should show elapsed time, got: %q", result)
	}
}

func TestRenderMinimalSessionInfo_ShowsBaseCommit(t *testing.T) {
	m := newTestModel()
	m.status.Session.StartCommit = "abc12345678"

	result := m.renderMinimalSessionInfo()

	if !strings.Contains(result, "BASE") {
		t.Errorf("minimal session info should show base commit, got: %q", result)
	}
	if !strings.Contains(result, "abc1234") {
		t.Errorf("minimal session info should show truncated commit hash, got: %q", result)
	}
}

func TestRenderMinimalSessionInfo_ShowsStartingMessage_WhenEmpty(t *testing.T) {
	m := newTestModel()
	m.status.Session.StartTime = time.Time{}
	m.status.Session.StartCommit = ""

	result := m.renderMinimalSessionInfo()

	if !strings.Contains(result, "Session starting") {
		t.Errorf("minimal session info should show starting message when empty, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderPlanRequirements
// =============================================================================

func TestRenderPlanRequirements_ShowsMustHave(t *testing.T) {
	m := newTestModel()
	m.status.Plan.MustHave = []string{"Feature A", "Feature B"}

	result := m.renderPlanRequirements()

	if !strings.Contains(result, "Must Have") {
		t.Errorf("plan requirements should show 'Must Have' header, got: %q", result)
	}
	if !strings.Contains(result, "Feature A") {
		t.Errorf("plan requirements should show must-have items, got: %q", result)
	}
}

func TestRenderPlanRequirements_ShowsShouldHave(t *testing.T) {
	m := newTestModel()
	m.status.Plan.ShouldHave = []string{"Nice feature"}

	result := m.renderPlanRequirements()

	if !strings.Contains(result, "Should Have") {
		t.Errorf("plan requirements should show 'Should Have' header, got: %q", result)
	}
	if !strings.Contains(result, "Nice feature") {
		t.Errorf("plan requirements should show should-have items, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - allGatesPassed
// =============================================================================

func TestAllGatesPassed_AllPassed_ReturnsTrue(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "passed"}

	if !m.allGatesPassed() {
		t.Error("allGatesPassed should return true when all gates passed")
	}
}

func TestAllGatesPassed_TestFailed_ReturnsFalse(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "failed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "passed"}

	if m.allGatesPassed() {
		t.Error("allGatesPassed should return false when test gate failed")
	}
}

func TestAllGatesPassed_LintFailed_ReturnsFalse(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "failed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "passed"}

	if m.allGatesPassed() {
		t.Error("allGatesPassed should return false when lint gate failed")
	}
}

func TestAllGatesPassed_TestSkipped_ReturnsTrue(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "skipped"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "passed"}

	if !m.allGatesPassed() {
		t.Error("allGatesPassed should return true when test is skipped (not failed)")
	}
}

func TestAllGatesPassed_TestPending_ReturnsTrue(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "pending"}
	m.status.Gates.Lint = GateResult{Status: "pending"}
	m.status.Gates.TypeCheck = GateResult{Status: "pending"}
	m.status.Gates.Build = GateResult{Status: "pending"}
	m.status.Gates.Format = GateResult{Status: "pending"}

	if !m.allGatesPassed() {
		t.Error("allGatesPassed should return true when gates are pending (not failed)")
	}
}

func TestAllGatesPassed_OptionalGateFailed_ReturnsFalse(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "failed"} // Optional gate
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "passed"}

	if m.allGatesPassed() {
		t.Error("allGatesPassed should return false when optional gate explicitly failed")
	}
}

func TestAllGatesPassed_OptionalGatePending_ReturnsTrue(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "pending"} // Optional gate pending
	m.status.Gates.Build = GateResult{Status: "pending"}
	m.status.Gates.Format = GateResult{Status: "pending"}

	if !m.allGatesPassed() {
		t.Error("allGatesPassed should return true when optional gates are pending")
	}
}

func TestAllGatesPassed_BuildFailed_ReturnsFalse(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "failed"}
	m.status.Gates.Format = GateResult{Status: "passed"}

	if m.allGatesPassed() {
		t.Error("allGatesPassed should return false when build gate failed")
	}
}

func TestAllGatesPassed_FormatFailed_ReturnsFalse(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "failed"}

	if m.allGatesPassed() {
		t.Error("allGatesPassed should return false when format gate failed")
	}
}

// =============================================================================
// Helper Function Tests - renderGatesExpanded
// =============================================================================

func TestRenderGatesExpanded_ShowsAllGates(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed", Command: "go test ./..."}
	m.status.Gates.Lint = GateResult{Status: "passed", Command: "golangci-lint run"}

	result := m.renderGatesExpanded()

	if !strings.Contains(result, "TEST") {
		t.Errorf("gates expanded should show TEST gate, got: %q", result)
	}
	if !strings.Contains(result, "LINT") {
		t.Errorf("gates expanded should show LINT gate, got: %q", result)
	}
	if !strings.Contains(result, "TYPECHECK") {
		t.Errorf("gates expanded should show TYPECHECK gate, got: %q", result)
	}
	if !strings.Contains(result, "BUILD") {
		t.Errorf("gates expanded should show BUILD gate, got: %q", result)
	}
	if !strings.Contains(result, "FORMAT") {
		t.Errorf("gates expanded should show FORMAT gate, got: %q", result)
	}
}

func TestRenderGatesExpanded_ShowsFailureCount(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "failed", Command: "go test"}
	m.status.GateFailureCounts.Test = 2

	result := m.renderGatesExpanded()

	if !strings.Contains(result, "2 fails") {
		t.Errorf("gates expanded should show failure count, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderGatesCompact
// =============================================================================

func TestRenderGatesCompact_ShowsPassedGates(t *testing.T) {
	m := newTestModel()
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}

	result := m.renderGatesCompact()

	// Should have checkmarks for passed gates
	if !strings.Contains(result, "TEST") {
		t.Errorf("gates compact should show TEST, got: %q", result)
	}
}

func TestRenderGatesCompact_ShowsSkippedGates(t *testing.T) {
	m := newTestModel()
	m.status.Gates.TypeCheck = GateResult{Status: "skipped"}

	result := m.renderGatesCompact()

	if !strings.Contains(result, "TYPECHECK") {
		t.Errorf("gates compact should show skipped gates, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderAgentsCompact
// =============================================================================

func TestRenderAgentsCompact_NoAgents_ShowsMessage(t *testing.T) {
	m := newTestModel()
	m.status.Agents = []AgentStatus{}

	result := m.renderAgentsCompact()

	if !strings.Contains(result, "No agents have run yet") {
		t.Errorf("agents compact should show message when empty, got: %q", result)
	}
}

func TestRenderAgentsCompact_ShowsDoneAgents(t *testing.T) {
	m := newTestModel()
	m.status.Agents = []AgentStatus{
		{Name: "code-reviewer", Status: "done"},
	}

	result := m.renderAgentsCompact()

	if !strings.Contains(result, "code-reviewer") {
		t.Errorf("agents compact should show agent name, got: %q", result)
	}
	if !strings.Contains(result, "[X]") {
		t.Errorf("agents compact should show done marker, got: %q", result)
	}
}

func TestRenderAgentsCompact_ShowsBlockers(t *testing.T) {
	m := newTestModel()
	m.status.Agents = []AgentStatus{
		{Name: "code-reviewer", Status: "done", Blockers: 2},
	}

	result := m.renderAgentsCompact()

	if !strings.Contains(result, "2B") {
		t.Errorf("agents compact should show blocker count, got: %q", result)
	}
}

func TestRenderAgentsCompact_ShowsWarnings(t *testing.T) {
	m := newTestModel()
	m.status.Agents = []AgentStatus{
		{Name: "code-reviewer", Status: "done", Warnings: 3},
	}

	result := m.renderAgentsCompact()

	if !strings.Contains(result, "3W") {
		t.Errorf("agents compact should show warning count, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderSessionSummary
// =============================================================================

func TestRenderSessionSummary_ShowsChunks(t *testing.T) {
	m := newTestModel()
	m.status.Stats.ChunksCompleted = 3
	m.status.Stats.ChunksTotal = 5

	result := m.renderSessionSummary()

	if !strings.Contains(result, "CHUNKS") {
		t.Errorf("session summary should show chunks, got: %q", result)
	}
	if !strings.Contains(result, "3/5") {
		t.Errorf("session summary should show chunk progress, got: %q", result)
	}
}

func TestRenderSessionSummary_ShowsCommits(t *testing.T) {
	m := newTestModel()
	m.status.Stats.CommitsMade = 7

	result := m.renderSessionSummary()

	if !strings.Contains(result, "COMMITS") {
		t.Errorf("session summary should show commits, got: %q", result)
	}
}

func TestRenderSessionSummary_ShowsElapsed(t *testing.T) {
	m := newTestModel()
	m.status.Session.StartTime = time.Now().Add(-15 * time.Minute)

	result := m.renderSessionSummary()

	if !strings.Contains(result, "ELAPSED") {
		t.Errorf("session summary should show elapsed time, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderFinalStats
// =============================================================================

func TestRenderFinalStats_ShowsComplete(t *testing.T) {
	m := newTestModel()

	result := m.renderFinalStats()

	if !strings.Contains(result, "Complete") {
		t.Errorf("final stats should show complete status, got: %q", result)
	}
}

func TestRenderFinalStats_ShowsChunksCompleted(t *testing.T) {
	m := newTestModel()
	m.status.Stats.ChunksCompleted = 10
	m.status.Stats.ChunksTotal = 10

	result := m.renderFinalStats()

	if !strings.Contains(result, "10/10") {
		t.Errorf("final stats should show chunks completed, got: %q", result)
	}
}

func TestRenderFinalStats_ShowsCommitsMade(t *testing.T) {
	m := newTestModel()
	m.status.Stats.CommitsMade = 5

	result := m.renderFinalStats()

	if !strings.Contains(result, "COMMITS") {
		t.Errorf("final stats should show commits made, got: %q", result)
	}
}

func TestRenderFinalStats_ShowsGatesPassed(t *testing.T) {
	m := newTestModel()
	m.status.Stats.GatesPassed = 5
	m.status.Stats.GatesFailed = 0

	result := m.renderFinalStats()

	if !strings.Contains(result, "GATES") {
		t.Errorf("final stats should show gates passed, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderCommitsExpanded
// =============================================================================

func TestRenderCommitsExpanded_NoCommits_ShowsMessage(t *testing.T) {
	m := newTestModel()
	m.status.Commits = []CommitInfo{}

	result := m.renderCommitsExpanded()

	if !strings.Contains(result, "NO COMMITS") {
		t.Errorf("commits expanded should show no commits message, got: %q", result)
	}
}

func TestRenderCommitsExpanded_ShowsCommits(t *testing.T) {
	m := newTestModel()
	m.status.Commits = []CommitInfo{
		{Hash: "abc1234567890", Message: "feat: add new feature"},
		{Hash: "def9876543210", Message: "fix: resolve bug"},
	}

	result := m.renderCommitsExpanded()

	if !strings.Contains(result, "abc1234") {
		t.Errorf("commits expanded should show truncated hash, got: %q", result)
	}
	if !strings.Contains(result, "add new feature") {
		t.Errorf("commits expanded should show commit message, got: %q", result)
	}
}

func TestRenderCommitsExpanded_TruncatesLongMessage(t *testing.T) {
	m := newTestModel()
	longMessage := "feat: this is a very long commit message that should definitely be truncated to fit the display"
	m.status.Commits = []CommitInfo{
		{Hash: "abc1234", Message: longMessage},
	}

	result := m.renderCommitsExpanded()

	// Message should be truncated with "..."
	if len(longMessage) <= 45 {
		t.Skip("test message not long enough to verify truncation")
	}
	if !strings.Contains(result, "...") {
		t.Errorf("commits expanded should truncate long messages, got: %q", result)
	}
}

func TestRenderCommitsExpanded_ShowsEarlierCommitsNote(t *testing.T) {
	m := newTestModel()
	// Create more than 10 commits
	for i := 0; i < 15; i++ {
		m.status.Commits = append(m.status.Commits, CommitInfo{
			Hash:    "abc1234",
			Message: "commit message",
		})
	}

	result := m.renderCommitsExpanded()

	if !strings.Contains(result, "earlier commits") {
		t.Errorf("commits expanded should show 'earlier commits' note when > 10 commits, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderStopBanner
// =============================================================================

func TestRenderStopBanner_ShowsReason(t *testing.T) {
	m := newTestModel()
	m.status.StopConditions.Active = true
	m.status.StopConditions.Reason = "manual_stop"

	result := m.renderStopBanner()

	if !strings.Contains(result, "STOPPED") {
		t.Errorf("stop banner should show STOPPED, got: %q", result)
	}
	if !strings.Contains(result, "manual_stop") {
		t.Errorf("stop banner should show reason, got: %q", result)
	}
}

func TestRenderStopBanner_ShowsGateFailureDetails(t *testing.T) {
	m := newTestModel()
	m.status.StopConditions.Active = true
	m.status.StopConditions.Reason = "gate_failure"
	m.status.StopConditions.Details = map[string]interface{}{
		"gate": "test",
	}

	result := m.renderStopBanner()

	if !strings.Contains(result, "test") {
		t.Errorf("stop banner should show failed gate name, got: %q", result)
	}
}

func TestRenderStopBanner_ShowsChunkIterationDetails(t *testing.T) {
	m := newTestModel()
	m.status.StopConditions.Active = true
	m.status.StopConditions.Reason = "chunk_iterations"
	m.status.StopConditions.Details = map[string]interface{}{
		"chunk_id": "3",
	}

	result := m.renderStopBanner()

	if !strings.Contains(result, "Chunk 3") {
		t.Errorf("stop banner should show chunk ID, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderActiveAgent
// =============================================================================

func TestRenderActiveAgent_NilAgent_ShowsMessage(t *testing.T) {
	m := newTestModel()
	m.status.ActiveAgent = nil

	result := m.renderActiveAgent()

	if !strings.Contains(result, "NO ACTIVE AGENT") {
		t.Errorf("active agent should show message when nil, got: %q", result)
	}
}

func TestRenderActiveAgent_ShowsAgentName(t *testing.T) {
	m := newTestModel()
	m.status.ActiveAgent = &ActiveAgentInfo{
		Name: "researcher",
	}

	result := m.renderActiveAgent()

	if !strings.Contains(result, "researcher") {
		t.Errorf("active agent should show agent name, got: %q", result)
	}
}

func TestRenderActiveAgent_ShowsTask(t *testing.T) {
	m := newTestModel()
	m.status.ActiveAgent = &ActiveAgentInfo{
		Name: "researcher",
		Task: "Analyzing code structure",
	}

	result := m.renderActiveAgent()

	if !strings.Contains(result, "Analyzing code structure") {
		t.Errorf("active agent should show task, got: %q", result)
	}
}

func TestRenderActiveAgent_ShowsProgress(t *testing.T) {
	m := newTestModel()
	m.status.ActiveAgent = &ActiveAgentInfo{
		Name:     "researcher",
		Progress: "Scanned 50 files",
	}

	result := m.renderActiveAgent()

	if !strings.Contains(result, "Scanned 50 files") {
		t.Errorf("active agent should show progress, got: %q", result)
	}
}

func TestRenderActiveAgent_ShowsRunningTime(t *testing.T) {
	m := newTestModel()
	m.status.ActiveAgent = &ActiveAgentInfo{
		Name:      "researcher",
		StartedAt: time.Now().Add(-30 * time.Second),
	}

	result := m.renderActiveAgent()

	if !strings.Contains(result, "Running") {
		t.Errorf("active agent should show running time, got: %q", result)
	}
}

// =============================================================================
// Helper Function Tests - renderProgressBar
// =============================================================================

func TestRenderProgressBar_ZeroMax_HandlesGracefully(t *testing.T) {
	m := newTestModel()

	// Should not panic with max=0
	result := m.renderProgressBar(0, 0, 10)

	if len(result) == 0 {
		t.Error("progress bar should return non-empty string even with max=0")
	}
}

func TestRenderProgressBar_FullProgress(t *testing.T) {
	m := newTestModel()

	result := m.renderProgressBar(10, 10, 10)

	// Should contain filled blocks (the exact character depends on styles)
	if len(result) == 0 {
		t.Error("progress bar should return non-empty string")
	}
}

func TestRenderProgressBar_OverMax_CapsAtMax(t *testing.T) {
	m := newTestModel()

	// Should not overflow
	result := m.renderProgressBar(15, 10, 10)

	if len(result) == 0 {
		t.Error("progress bar should handle current > max gracefully")
	}
}

// =============================================================================
// Integration Tests - View dispatch with populated data
// =============================================================================

func TestView_PlanPhase_WithFullData(t *testing.T) {
	m := newTestModelWithPhase("plan")
	m.status.Session.StartTime = time.Now().Add(-5 * time.Minute)
	m.status.Session.StartCommit = "abc12345"
	m.status.ActiveAgent = &ActiveAgentInfo{
		Name: "researcher",
		Task: "Understanding spec",
	}
	m.status.CurrentTask = TaskInfo{
		Name:   "Parse PRD",
		Status: "in_progress",
	}
	m.status.Plan.MustHave = []string{"Feature A"}

	result := m.View()

	// Verify all sections are present
	if !strings.Contains(result, "PLANNING") {
		t.Error("plan phase should show PLANNING header")
	}
	if !strings.Contains(result, "researcher") {
		t.Error("plan phase should show active agent")
	}
	if !strings.Contains(result, "Parse PRD") {
		t.Error("plan phase should show current task")
	}
	if !strings.Contains(result, "Feature A") {
		t.Error("plan phase should show requirements")
	}
}

func TestView_ImplementPhase_WithFullData(t *testing.T) {
	m := newTestModelWithPhase("implement")
	m.status.Chunks = []ChunkInfo{
		{ID: 1, Name: "Setup", Status: "completed"},
		{ID: 2, Name: "Core", Status: "in_progress"},
	}
	m.status.Commits = []CommitInfo{
		{Hash: "abc1234", Message: "Initial setup"},
	}
	m.status.Gates.Test = GateResult{Status: "passed", Command: "go test"}
	m.status.Agents = []AgentStatus{
		{Name: "test-writer", Status: "done"},
	}

	result := m.View()

	if !strings.Contains(result, "IMPLEMENTING") {
		t.Error("implement phase should show IMPLEMENTING header")
	}
	if !strings.Contains(result, "Setup") {
		t.Error("implement phase should show chunks")
	}
	if !strings.Contains(result, "test-writer") {
		t.Error("implement phase should show agents")
	}
}

func TestView_ReviewPhase_WithAllGatesPassed(t *testing.T) {
	m := newTestModelWithPhase("review")
	m.status.Gates.Test = GateResult{Status: "passed"}
	m.status.Gates.Lint = GateResult{Status: "passed"}
	m.status.Gates.TypeCheck = GateResult{Status: "passed"}
	m.status.Gates.Build = GateResult{Status: "passed"}
	m.status.Gates.Format = GateResult{Status: "passed"}
	m.status.Agents = []AgentStatus{
		{Name: "code-reviewer", Status: "done"},
	}

	result := m.View()

	if !strings.Contains(result, "FINAL REVIEW") {
		t.Error("review phase should show FINAL REVIEW header")
	}
	if !strings.Contains(result, "ALL PASSED") {
		t.Error("review phase should show ALL PASSED when all gates pass")
	}
}

func TestView_CompletePhase_WithFullData(t *testing.T) {
	m := newTestModelWithPhase("complete")
	m.status.Session.StartTime = time.Now().Add(-30 * time.Minute)
	m.status.Stats.ChunksCompleted = 5
	m.status.Stats.ChunksTotal = 5
	m.status.Stats.CommitsMade = 3
	m.status.Stats.GatesPassed = 5
	m.status.Commits = []CommitInfo{
		{Hash: "abc1234", Message: "First commit"},
		{Hash: "def5678", Message: "Second commit"},
	}

	result := m.View()

	if !strings.Contains(result, "COMPLETE") {
		t.Error("complete phase should show COMPLETE header")
	}
	if !strings.Contains(result, "Session completed successfully") {
		t.Error("complete phase should show success message")
	}
	if !strings.Contains(result, "Commits Made") {
		t.Error("complete phase should show commits section")
	}
}

// =============================================================================
// Test Helpers
// =============================================================================

type testError struct {
	msg string
}

func (e *testError) Error() string {
	return e.msg
}
