package main

import (
	"fmt"
	"os"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

const statusFile = ".wiggum-status.json"

// Pastel color palette - soft, modern aesthetic
var (
	pastelMint     = lipgloss.Color("#98D8C8") // Primary - soft mint green (success)
	pastelBlue     = lipgloss.Color("#7EC8E3") // Secondary - light sky blue (info)
	pastelPeach    = lipgloss.Color("#FFCBA4") // Warning - soft peach (in progress)
	pastelPink     = lipgloss.Color("#FFB3BA") // Error - soft coral pink (failed)
	pastelLavender = lipgloss.Color("#C9B1FF") // Accent - soft lavender (active)
	pastelYellow   = lipgloss.Color("#FDFD96") // Highlight - soft lemon
	pastelGray     = lipgloss.Color("#9E9E9E") // Dim text
	darkText       = lipgloss.Color("#2D2D2D") // Dark text for contrast

	// Styles
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(darkText).
			Background(pastelMint).
			Padding(0, 1)

	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(pastelBlue).
			Underline(true)

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.Border{
			Top:         "─",
			Bottom:      "─",
			Left:        "│",
			Right:       "│",
			TopLeft:     "╭",
			TopRight:    "╮",
			BottomLeft:  "╰",
			BottomRight: "╯",
		}).
		BorderForeground(pastelGray).
		Padding(0, 1)

	activeBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.Border{
			Top:         "━",
			Bottom:      "━",
			Left:        "┃",
			Right:       "┃",
			TopLeft:     "┏",
			TopRight:    "┓",
			BottomLeft:  "┗",
			BottomRight: "┛",
		}).
		BorderForeground(pastelLavender).
		Padding(0, 1)

	// Stop banner style - prominent red
	stopBannerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(darkText).
			Background(pastelPink).
			Padding(0, 2)

	passedStyle = lipgloss.NewStyle().
			Foreground(pastelMint).
			Bold(true)

	failedStyle = lipgloss.NewStyle().
			Foreground(pastelPink).
			Bold(true)

	pendingStyle = lipgloss.NewStyle().
			Foreground(pastelGray)

	runningStyle = lipgloss.NewStyle().
			Foreground(pastelPeach).
			Bold(true)

	textStyle = lipgloss.NewStyle().
			Foreground(pastelBlue)

	dimStyle = lipgloss.NewStyle().
			Foreground(pastelGray)

	blinkFrames = []string{"◉", "◎", "○", "◎", "◉", "●"}
)

type model struct {
	status     *WiggumStatus
	err        error
	width      int
	height     int
	lastUpdate time.Time
	frame      int
}

type tickMsg time.Time
type statusMsg *WiggumStatus
type errMsg error

func tick() tea.Cmd {
	return tea.Tick(250*time.Millisecond, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func loadStatusCmd() tea.Msg {
	status, err := LoadStatus(statusFile)
	if err != nil {
		return errMsg(err)
	}
	return statusMsg(status)
}

func (m model) Init() tea.Cmd {
	return tea.Batch(tick(), loadStatusCmd)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "r":
			return m, loadStatusCmd
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height

	case tickMsg:
		m.lastUpdate = time.Time(msg)
		m.frame = (m.frame + 1) % len(blinkFrames)
		return m, tea.Batch(tick(), loadStatusCmd)

	case statusMsg:
		m.status = msg
		m.err = nil

	case errMsg:
		m.err = msg
		if m.status == nil {
			m.status = NewEmptyStatus()
		}
	}

	return m, nil
}

func (m model) View() string {
	if m.width == 0 {
		return textStyle.Render("INITIALIZING...")
	}

	// Guard against nil status
	if m.status == nil {
		return m.renderStandbyPhase()
	}

	// Dispatch to phase-specific view
	phase := m.status.Session.Phase
	if m.err != nil && phase == "" {
		phase = "standby"
	}

	switch phase {
	case "plan":
		return m.renderPlanPhase()
	case "implement":
		return m.renderImplementPhase()
	case "review":
		return m.renderReviewPhase()
	case "complete":
		return m.renderCompletePhase()
	default:
		return m.renderStandbyPhase()
	}
}

// renderCommonHeader renders the header bar common to all phases
func (m model) renderCommonHeader(phaseTitle string) string {
	var b strings.Builder
	separator := strings.Repeat("─", m.width)

	b.WriteString(dimStyle.Render(separator))
	b.WriteString("\n")

	title := titleStyle.Render(fmt.Sprintf(" ✦ %s ✦ ", phaseTitle))
	timestamp := dimStyle.Render(fmt.Sprintf("⏱ %s", time.Now().Format("15:04:05")))
	padding := strings.Repeat(" ", max(0, m.width-lipgloss.Width(title)-lipgloss.Width(timestamp)-2))
	b.WriteString(title + padding + timestamp)
	b.WriteString("\n")

	b.WriteString(dimStyle.Render(separator))
	b.WriteString("\n")

	// Stop condition banner (if active)
	if m.status.StopConditions.Active {
		b.WriteString("\n")
		b.WriteString(m.renderStopBanner())
		b.WriteString("\n")
	}

	return b.String()
}

// renderCommonFooter renders the footer with phase-specific hints
func (m model) renderCommonFooter(hint string, status string, statusStyle lipgloss.Style) string {
	var b strings.Builder
	separator := strings.Repeat("─", m.width)

	b.WriteString("\n")
	b.WriteString(dimStyle.Render(separator))
	b.WriteString("\n")

	footerLeft := dimStyle.Render(fmt.Sprintf(" [Q] Quit  [R] Refresh    %s", hint))
	footerRight := statusStyle.Render(status)

	padding := strings.Repeat(" ", max(0, m.width-lipgloss.Width(footerLeft)-lipgloss.Width(footerRight)-2))
	b.WriteString(footerLeft + padding + footerRight + " ")

	return b.String()
}

// renderStandbyPhase shows minimal view when no session is active
func (m model) renderStandbyPhase() string {
	var b strings.Builder

	b.WriteString(m.renderCommonHeader("WIGGUM"))
	b.WriteString("\n")

	// Centered waiting message
	blink := blinkFrames[m.frame]
	waitingMsg := fmt.Sprintf("%s Awaiting session... %s", blink, blink)
	helpMsg := "Run /wiggum to start a session"

	// Center the messages
	waitingWidth := lipgloss.Width(waitingMsg)
	helpWidth := lipgloss.Width(helpMsg)
	waitingPad := (m.width - waitingWidth) / 2
	helpPad := (m.width - helpWidth) / 2

	b.WriteString("\n\n")
	b.WriteString(strings.Repeat(" ", max(0, waitingPad)))
	b.WriteString(runningStyle.Render(waitingMsg))
	b.WriteString("\n\n")
	b.WriteString(strings.Repeat(" ", max(0, helpPad)))
	b.WriteString(dimStyle.Render(helpMsg))
	b.WriteString("\n\n")

	if m.err != nil {
		errMsg := fmt.Sprintf("[%v]", m.err)
		errWidth := lipgloss.Width(errMsg)
		errPad := (m.width - errWidth) / 2
		b.WriteString(strings.Repeat(" ", max(0, errPad)))
		b.WriteString(dimStyle.Render(errMsg))
		b.WriteString("\n")
	}

	b.WriteString(m.renderCommonFooter("", "○ Standby", dimStyle))

	return b.String()
}

// renderPlanPhase shows focused view during planning
func (m model) renderPlanPhase() string {
	var b strings.Builder

	b.WriteString(m.renderCommonHeader("PLANNING"))
	b.WriteString("\n")

	// Single column layout for plan phase
	contentWidth := m.width - 4

	// Session info (minimal)
	b.WriteString(headerStyle.Render("◈ Session"))
	b.WriteString("\n")
	sessionContent := m.renderMinimalSessionInfo()
	b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(boxStyle.Render(sessionContent)))
	b.WriteString("\n\n")

	// Active Agent (prominent if running)
	if m.status.ActiveAgent != nil {
		b.WriteString(headerStyle.Render("◈ Active Agent"))
		b.WriteString("\n")
		agentContent := m.renderActiveAgent()
		b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(activeBoxStyle.Render(agentContent)))
		b.WriteString("\n\n")
	}

	// Current Task (if any)
	if m.status.CurrentTask.Name != "" {
		b.WriteString(headerStyle.Render("◈ Current Task"))
		b.WriteString("\n")
		taskContent := m.renderCurrentTask()
		style := boxStyle
		if m.status.CurrentTask.Status == "in_progress" {
			style = activeBoxStyle
		}
		b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(style.Render(taskContent)))
		b.WriteString("\n")
	}

	// Plan requirements if populated
	if len(m.status.Plan.MustHave) > 0 || len(m.status.Plan.ShouldHave) > 0 {
		b.WriteString("\n")
		b.WriteString(headerStyle.Render("◈ Requirements"))
		b.WriteString("\n")
		planContent := m.renderPlanRequirements()
		b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(boxStyle.Render(planContent)))
		b.WriteString("\n")
	}

	b.WriteString(m.renderCommonFooter("", "● Planning", runningStyle))

	return b.String()
}

// renderImplementPhase shows full view during implementation
func (m model) renderImplementPhase() string {
	var b strings.Builder

	b.WriteString(m.renderCommonHeader("IMPLEMENTING"))
	b.WriteString("\n")

	// Two-column layout
	leftCol := m.renderImplementLeftColumn()
	rightCol := m.renderImplementRightColumn()

	leftWidth := m.width/2 - 2
	rightWidth := m.width/2 - 2

	leftCol = lipgloss.NewStyle().Width(leftWidth).Render(leftCol)
	rightCol = lipgloss.NewStyle().Width(rightWidth).Render(rightCol)

	columns := lipgloss.JoinHorizontal(lipgloss.Top, leftCol, "  ", rightCol)
	b.WriteString(columns)

	b.WriteString(m.renderCommonFooter("Watch gates", "● Implementing", runningStyle))

	return b.String()
}

// renderReviewPhase shows gates-focused view during review
func (m model) renderReviewPhase() string {
	var b strings.Builder

	b.WriteString(m.renderCommonHeader("FINAL REVIEW"))
	b.WriteString("\n")

	contentWidth := m.width - 4

	// Prominent gates section at top
	allPassed := m.allGatesPassed()
	gatesHeader := "◈ GATES"
	if allPassed {
		gatesHeader = "◈ GATES - ALL PASSED ✓"
	}
	b.WriteString(headerStyle.Render(gatesHeader))
	b.WriteString("\n")
	gatesContent := m.renderGatesExpanded()
	b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(activeBoxStyle.Render(gatesContent)))
	b.WriteString("\n\n")

	// Active agent if running
	if m.status.ActiveAgent != nil {
		b.WriteString(headerStyle.Render("◈ Active Agent"))
		b.WriteString("\n")
		agentContent := m.renderActiveAgent()
		b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(activeBoxStyle.Render(agentContent)))
		b.WriteString("\n\n")
	}

	// Agent status (important for review)
	b.WriteString(headerStyle.Render("◈ Agent Status"))
	b.WriteString("\n")
	agentsContent := m.renderAgentsCompact()
	b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(boxStyle.Render(agentsContent)))
	b.WriteString("\n\n")

	// Session summary
	b.WriteString(headerStyle.Render("◈ Session Summary"))
	b.WriteString("\n")
	summaryContent := m.renderSessionSummary()
	b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(boxStyle.Render(summaryContent)))
	b.WriteString("\n")

	hint := "All gates must show ✓"
	b.WriteString(m.renderCommonFooter(hint, "● Reviewing", runningStyle))

	return b.String()
}

// renderCompletePhase shows celebration view when done
func (m model) renderCompletePhase() string {
	var b strings.Builder

	b.WriteString(m.renderCommonHeader("COMPLETE ✓"))
	b.WriteString("\n")

	contentWidth := m.width - 4

	// Success message
	successMsg := "Session completed successfully"
	successWidth := lipgloss.Width(successMsg)
	successPad := (m.width - successWidth) / 2
	b.WriteString(strings.Repeat(" ", max(0, successPad)))
	b.WriteString(passedStyle.Render(successMsg))
	b.WriteString("\n\n")

	// Final stats
	b.WriteString(headerStyle.Render("◈ Final Stats"))
	b.WriteString("\n")
	statsContent := m.renderFinalStats()
	b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(boxStyle.Render(statsContent)))
	b.WriteString("\n\n")

	// All commits (expanded)
	if len(m.status.Commits) > 0 {
		b.WriteString(headerStyle.Render("◈ Commits Made"))
		b.WriteString("\n")
		commitsContent := m.renderCommitsExpanded()
		b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(boxStyle.Render(commitsContent)))
		b.WriteString("\n\n")
	}

	// Gates summary (compact)
	b.WriteString(headerStyle.Render("◈ Gates (All Passed)"))
	b.WriteString("\n")
	gatesContent := m.renderGatesCompact()
	b.WriteString(lipgloss.NewStyle().Width(contentWidth).Render(boxStyle.Render(gatesContent)))
	b.WriteString("\n")

	b.WriteString(m.renderCommonFooter("", "✓ Complete", passedStyle))

	return b.String()
}

// renderImplementLeftColumn renders left column for implement phase
func (m model) renderImplementLeftColumn() string {
	var b strings.Builder

	// Active Agent (if running)
	if m.status.ActiveAgent != nil {
		b.WriteString(headerStyle.Render("◈ Active Agent"))
		b.WriteString("\n")
		agentContent := m.renderActiveAgent()
		b.WriteString(activeBoxStyle.Render(agentContent))
		b.WriteString("\n\n")
	}

	// Session Info
	b.WriteString(headerStyle.Render("◈ Session"))
	b.WriteString("\n")
	sessionContent := m.renderSessionInfo()
	b.WriteString(boxStyle.Render(sessionContent))
	b.WriteString("\n\n")

	// Current Task (if any)
	if m.status.CurrentTask.Name != "" {
		b.WriteString(headerStyle.Render("◈ Active Task"))
		b.WriteString("\n")
		taskContent := m.renderCurrentTask()
		style := boxStyle
		if m.status.CurrentTask.Status == "in_progress" {
			style = activeBoxStyle
		}
		b.WriteString(style.Render(taskContent))
		b.WriteString("\n\n")
	}

	// Chunks (if defined)
	if len(m.status.Chunks) > 0 {
		b.WriteString(headerStyle.Render("◈ Chunks"))
		b.WriteString("\n")
		chunksContent := m.renderChunks()
		b.WriteString(boxStyle.Render(chunksContent))
	}

	return b.String()
}

// renderImplementRightColumn renders right column for implement phase
func (m model) renderImplementRightColumn() string {
	var b strings.Builder

	// Gates (always show in implement)
	b.WriteString(headerStyle.Render("◈ Gates"))
	b.WriteString("\n")
	gatesContent := m.renderGates()
	b.WriteString(boxStyle.Render(gatesContent))
	b.WriteString("\n\n")

	// Agents
	b.WriteString(headerStyle.Render("◈ Agents"))
	b.WriteString("\n")
	agentsContent := m.renderAgents()
	b.WriteString(boxStyle.Render(agentsContent))
	b.WriteString("\n\n")

	// Commits (if any)
	if len(m.status.Commits) > 0 {
		b.WriteString(headerStyle.Render("◈ Commits"))
		b.WriteString("\n")
		commitsContent := m.renderCommits()
		b.WriteString(boxStyle.Render(commitsContent))
	}

	return b.String()
}

// renderMinimalSessionInfo shows just elapsed time for plan phase
func (m model) renderMinimalSessionInfo() string {
	s := m.status
	var lines []string

	if !s.Session.StartTime.IsZero() {
		elapsed := time.Since(s.Session.StartTime).Round(time.Second)
		lines = append(lines, fmt.Sprintf("ELAPSED: %s", textStyle.Render(elapsed.String())))
	}

	if s.Session.StartCommit != "" && len(s.Session.StartCommit) >= 7 {
		lines = append(lines, fmt.Sprintf("BASE: %s", dimStyle.Render(s.Session.StartCommit[:7])))
	}

	if len(lines) == 0 {
		return dimStyle.Render("Session starting...")
	}

	return strings.Join(lines, "    ")
}

// renderPlanRequirements shows plan requirements during planning
func (m model) renderPlanRequirements() string {
	p := m.status.Plan
	var lines []string

	if len(p.MustHave) > 0 {
		lines = append(lines, textStyle.Render("Must Have:"))
		for _, r := range p.MustHave {
			lines = append(lines, fmt.Sprintf("  • %s", r))
		}
	}

	if len(p.ShouldHave) > 0 {
		if len(lines) > 0 {
			lines = append(lines, "")
		}
		lines = append(lines, textStyle.Render("Should Have:"))
		for _, r := range p.ShouldHave {
			lines = append(lines, fmt.Sprintf("  • %s", dimStyle.Render(r)))
		}
	}

	return strings.Join(lines, "\n")
}

// renderGatesExpanded shows gates with more detail for review phase
func (m model) renderGatesExpanded() string {
	g := m.status.Gates
	fc := m.status.GateFailureCounts

	gates := []struct {
		name      string
		result    GateResult
		failCount int
	}{
		{"TEST", g.Test, fc.Test},
		{"LINT", g.Lint, fc.Lint},
		{"TYPECHECK", g.TypeCheck, fc.TypeCheck},
		{"BUILD", g.Build, fc.Build},
		{"FORMAT", g.Format, fc.Format},
	}

	var lines []string
	for _, gate := range gates {
		icon := gateIcon(gate.result.Status)
		cmd := gate.result.Command
		if cmd == "" {
			cmd = "---"
		}
		if len(cmd) > 25 {
			cmd = cmd[:22] + "..."
		}

		var line string
		status := fmt.Sprintf("%-9s", gate.name)

		switch gate.result.Status {
		case "passed":
			line = fmt.Sprintf("%s %s %s", passedStyle.Render(icon), passedStyle.Render(status), dimStyle.Render(cmd))
		case "failed":
			line = fmt.Sprintf("%s %s %s", failedStyle.Render(icon), failedStyle.Render(status), dimStyle.Render(cmd))
		case "running":
			blink := blinkFrames[m.frame]
			line = fmt.Sprintf("%s %s %s %s", runningStyle.Render(icon), runningStyle.Render(status), dimStyle.Render(cmd), runningStyle.Render(blink))
		default:
			line = fmt.Sprintf("%s %s %s", dimStyle.Render(icon), dimStyle.Render(status), dimStyle.Render(cmd))
		}

		if gate.failCount > 0 {
			line += failedStyle.Render(fmt.Sprintf(" [%d fails]", gate.failCount))
		}

		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

// renderAgentsCompact shows agent status in compact form
func (m model) renderAgentsCompact() string {
	agents := m.status.Agents
	if len(agents) == 0 {
		return dimStyle.Render("No agents have run yet")
	}

	var lines []string
	for _, a := range agents {
		icon := "[ ]"
		style := dimStyle
		if a.Status == "done" {
			icon = "[X]"
			style = passedStyle
		} else if a.Status == "active" {
			icon = "[" + blinkFrames[m.frame] + "]"
			style = runningStyle
		}

		line := style.Render(fmt.Sprintf("%s %-15s", icon, a.Name))

		if a.Blockers > 0 {
			line += failedStyle.Render(fmt.Sprintf(" %dB", a.Blockers))
		}
		if a.Warnings > 0 {
			line += runningStyle.Render(fmt.Sprintf(" %dW", a.Warnings))
		}

		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

// renderSessionSummary shows compact session summary for review
func (m model) renderSessionSummary() string {
	s := m.status
	var parts []string

	parts = append(parts, fmt.Sprintf("CHUNKS: %s", textStyle.Render(fmt.Sprintf("%d/%d", s.Stats.ChunksCompleted, s.Stats.ChunksTotal))))
	parts = append(parts, fmt.Sprintf("COMMITS: %s", textStyle.Render(fmt.Sprintf("%d", s.Stats.CommitsMade))))

	if !s.Session.StartTime.IsZero() {
		elapsed := time.Since(s.Session.StartTime).Round(time.Second)
		parts = append(parts, fmt.Sprintf("ELAPSED: %s", textStyle.Render(elapsed.String())))
	}

	return strings.Join(parts, "    ")
}

// renderFinalStats shows final stats for complete phase
func (m model) renderFinalStats() string {
	s := m.status
	var lines []string

	lines = append(lines, fmt.Sprintf("PHASE: %s", passedStyle.Render("✓ Complete")))

	if !s.Session.StartTime.IsZero() {
		elapsed := time.Since(s.Session.StartTime).Round(time.Second)
		lines = append(lines, fmt.Sprintf("ELAPSED: %s", textStyle.Render(elapsed.String())))
	}

	lines = append(lines, fmt.Sprintf("CHUNKS: %s completed", passedStyle.Render(fmt.Sprintf("%d/%d", s.Stats.ChunksCompleted, s.Stats.ChunksTotal))))
	lines = append(lines, fmt.Sprintf("COMMITS: %s made", passedStyle.Render(fmt.Sprintf("%d", s.Stats.CommitsMade))))
	lines = append(lines, fmt.Sprintf("GATES: %s passed", passedStyle.Render(fmt.Sprintf("%d/%d", s.Stats.GatesPassed, s.Stats.GatesPassed+s.Stats.GatesFailed))))

	return strings.Join(lines, "\n")
}

// renderCommitsExpanded shows all commits for complete phase
func (m model) renderCommitsExpanded() string {
	commits := m.status.Commits
	if len(commits) == 0 {
		return dimStyle.Render("< NO COMMITS >")
	}

	var lines []string
	// Show up to 10 commits in complete view
	maxShow := 10
	start := 0
	if len(commits) > maxShow {
		start = len(commits) - maxShow
		lines = append(lines, dimStyle.Render(fmt.Sprintf("... and %d earlier commits", start)))
	}

	for _, c := range commits[start:] {
		hash := c.Hash
		if len(hash) > 7 {
			hash = hash[:7]
		}
		msg := c.Message
		if len(msg) > 45 {
			msg = msg[:42] + "..."
		}
		line := fmt.Sprintf("%s %s", passedStyle.Render(hash), textStyle.Render(msg))
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

// renderGatesCompact shows gates in single line for complete phase
func (m model) renderGatesCompact() string {
	g := m.status.Gates

	gates := []struct {
		name   string
		status string
	}{
		{"TEST", g.Test.Status},
		{"LINT", g.Lint.Status},
		{"TYPECHECK", g.TypeCheck.Status},
		{"BUILD", g.Build.Status},
		{"FORMAT", g.Format.Status},
	}

	var parts []string
	for _, gate := range gates {
		if gate.status == "passed" {
			parts = append(parts, passedStyle.Render(fmt.Sprintf("✓ %s", gate.name)))
		} else if gate.status == "skipped" || gate.status == "pending" {
			parts = append(parts, dimStyle.Render(fmt.Sprintf("− %s", gate.name)))
		} else {
			parts = append(parts, failedStyle.Render(fmt.Sprintf("✗ %s", gate.name)))
		}
	}

	return strings.Join(parts, "  ")
}

// allGatesPassed checks if all required gates passed
func (m model) allGatesPassed() bool {
	g := m.status.Gates

	// Required gates must not be failed or running
	requiredGates := []GateResult{g.Test, g.Lint}
	for _, gate := range requiredGates {
		if gate.Status == "failed" || gate.Status == "running" {
			return false
		}
	}

	// Optional gates only fail if explicitly failed
	optionalGates := []GateResult{g.TypeCheck, g.Build, g.Format}
	for _, gate := range optionalGates {
		if gate.Status == "failed" {
			return false
		}
	}
	return true
}

// renderStopBanner shows the stop condition prominently
func (m model) renderStopBanner() string {
	sc := m.status.StopConditions
	blink := blinkFrames[m.frame]

	reason := sc.Reason
	if reason == "gate_failure" {
		if gate, ok := sc.Details["gate"].(string); ok {
			reason = fmt.Sprintf("Gate '%s' failed too many times", gate)
		}
	} else if reason == "chunk_iterations" {
		if chunkID, ok := sc.Details["chunk_id"].(string); ok {
			reason = fmt.Sprintf("Chunk %s exceeded iteration limit", chunkID)
		}
	}

	banner := stopBannerStyle.Render(fmt.Sprintf(" %s STOPPED: %s %s ", blink, reason, blink))

	// Center the banner
	bannerWidth := lipgloss.Width(banner)
	leftPad := (m.width - bannerWidth) / 2
	if leftPad < 0 {
		leftPad = 0
	}

	return strings.Repeat(" ", leftPad) + banner
}

// renderActiveAgent shows the currently running agent
func (m model) renderActiveAgent() string {
	agent := m.status.ActiveAgent
	if agent == nil {
		return dimStyle.Render("< NO ACTIVE AGENT >")
	}

	var lines []string

	// Agent name with blinking indicator
	blink := blinkFrames[m.frame]
	name := runningStyle.Render(fmt.Sprintf("%s %s", blink, agent.Name))
	lines = append(lines, name)

	// Task description
	if agent.Task != "" {
		lines = append(lines, textStyle.Render(agent.Task))
	}

	// Progress
	if agent.Progress != "" {
		lines = append(lines, dimStyle.Render(agent.Progress))
	}

	// Running time
	if !agent.StartedAt.IsZero() {
		elapsed := time.Since(agent.StartedAt).Round(time.Second)
		lines = append(lines, "")
		lines = append(lines, dimStyle.Render(fmt.Sprintf("Running: %s", elapsed.String())))
	}

	return strings.Join(lines, "\n")
}

func (m model) renderSessionInfo() string {
	s := m.status
	var lines []string

	phase := s.Session.Phase
	if phase == "" {
		phase = "STANDBY"
	}

	// Progress bar for iterations
	iterBar := m.renderProgressBar(s.Session.Iteration, s.Session.MaxIterations, 15)

	lines = append(lines, fmt.Sprintf("PHASE.....: %s", stylePhase(phase)))
	lines = append(lines, fmt.Sprintf("ITERATION.: [%s] %d/%d", iterBar, s.Session.Iteration, s.Session.MaxIterations))

	if !s.Session.StartTime.IsZero() {
		elapsed := time.Since(s.Session.StartTime).Round(time.Second)
		lines = append(lines, fmt.Sprintf("ELAPSED...: %s", textStyle.Render(elapsed.String())))
	} else {
		lines = append(lines, fmt.Sprintf("ELAPSED...: %s", dimStyle.Render("--:--:--")))
	}

	if s.Session.StartCommit != "" && len(s.Session.StartCommit) >= 7 {
		lines = append(lines, fmt.Sprintf("BASE......: %s", dimStyle.Render(s.Session.StartCommit[:7])))
	}

	// Stats
	lines = append(lines, "")
	lines = append(lines, dimStyle.Render(fmt.Sprintf("CHUNKS: %d/%d  COMMITS: %d  GATES: %d/%d",
		s.Stats.ChunksCompleted, s.Stats.ChunksTotal,
		s.Stats.CommitsMade,
		s.Stats.GatesPassed, s.Stats.GatesPassed+s.Stats.GatesFailed)))

	return strings.Join(lines, "\n")
}

func (m model) renderProgressBar(current, max, width int) string {
	if max == 0 {
		max = 1
	}
	filled := (current * width) / max
	if filled > width {
		filled = width
	}

	bar := strings.Repeat("█", filled) + strings.Repeat("░", width-filled)
	return textStyle.Render(bar)
}

func (m model) renderCurrentTask() string {
	t := m.status.CurrentTask

	if t.Name == "" {
		return dimStyle.Render("< NO ACTIVE TASK >")
	}

	var lines []string

	// Task name with blinking indicator if in progress
	name := t.Name
	if t.Status == "in_progress" {
		blink := blinkFrames[m.frame]
		name = fmt.Sprintf("%s %s", runningStyle.Render(blink), textStyle.Render(name))
	} else {
		name = textStyle.Render(name)
	}
	lines = append(lines, name)

	if t.Description != "" {
		lines = append(lines, dimStyle.Render(t.Description))
	}

	lines = append(lines, "")
	lines = append(lines, fmt.Sprintf("STATUS: %s    ATTEMPT: %s",
		styleStatus(t.Status),
		textStyle.Render(fmt.Sprintf("%d/%d", t.Attempt, t.MaxAttempts))))

	return strings.Join(lines, "\n")
}

func (m model) renderChunks() string {
	chunks := m.status.Chunks

	if len(chunks) == 0 {
		return dimStyle.Render("< NO CHUNKS DEFINED >")
	}

	var lines []string
	for _, c := range chunks {
		icon := chunkIcon(c.Status)
		num := fmt.Sprintf("%02d", c.ID)

		// Get iteration count for this chunk
		iterCount := 0
		if m.status.ChunkIterationCounts != nil {
			if count, ok := m.status.ChunkIterationCounts[fmt.Sprintf("%d", c.ID)]; ok {
				iterCount = count
			}
		}

		var line string
		switch c.Status {
		case "completed":
			line = passedStyle.Render(fmt.Sprintf("%s [%s] %s", icon, num, c.Name))
		case "in_progress":
			blink := blinkFrames[m.frame]
			line = runningStyle.Render(fmt.Sprintf("%s [%s] %s %s", icon, num, c.Name, blink))
			// Show iteration count for in-progress chunks
			if iterCount > 0 {
				maxIter := m.status.Limits.MaxIterationsPerChunk
				if maxIter == 0 {
					maxIter = 5
				}
				iterStyle := dimStyle
				if iterCount >= maxIter {
					iterStyle = failedStyle
				} else if iterCount > maxIter/2 {
					iterStyle = runningStyle
				}
				line += iterStyle.Render(fmt.Sprintf(" [%d/%d]", iterCount, maxIter))
			}
		case "failed":
			line = failedStyle.Render(fmt.Sprintf("%s [%s] %s", icon, num, c.Name))
		default:
			line = dimStyle.Render(fmt.Sprintf("%s [%s] %s", icon, num, c.Name))
		}
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m model) renderGates() string {
	g := m.status.Gates
	fc := m.status.GateFailureCounts
	maxFail := m.status.Limits.MaxGateFailures
	if maxFail == 0 {
		maxFail = 3
	}

	gates := []struct {
		name      string
		result    GateResult
		failCount int
	}{
		{"TEST", g.Test, fc.Test},
		{"LINT", g.Lint, fc.Lint},
		{"TYPECHECK", g.TypeCheck, fc.TypeCheck},
		{"BUILD", g.Build, fc.Build},
		{"FORMAT", g.Format, fc.Format},
	}

	var lines []string
	for _, gate := range gates {
		icon := gateIcon(gate.result.Status)
		cmd := gate.result.Command
		if cmd == "" {
			cmd = "---"
		}
		if len(cmd) > 15 {
			cmd = cmd[:12] + "..."
		}

		var line string
		status := fmt.Sprintf("%-9s", gate.name)

		switch gate.result.Status {
		case "passed":
			line = fmt.Sprintf("%s %s %s", passedStyle.Render(icon), passedStyle.Render(status), dimStyle.Render(cmd))
		case "failed":
			line = fmt.Sprintf("%s %s %s", failedStyle.Render(icon), failedStyle.Render(status), dimStyle.Render(cmd))
		case "running":
			blink := blinkFrames[m.frame]
			line = fmt.Sprintf("%s %s %s %s", runningStyle.Render(icon), runningStyle.Render(status), dimStyle.Render(cmd), runningStyle.Render(blink))
		default:
			line = fmt.Sprintf("%s %s %s", dimStyle.Render(icon), dimStyle.Render(status), dimStyle.Render(cmd))
		}

		// Add failure count indicator
		if gate.failCount > 0 {
			countStyle := runningStyle
			if gate.failCount >= maxFail {
				countStyle = failedStyle
			}
			line += countStyle.Render(fmt.Sprintf(" [%d/%d]", gate.failCount, maxFail))
		}

		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m model) renderAgents() string {
	agents := m.status.Agents

	if len(agents) == 0 {
		// Show default agents
		defaultAgents := []string{"researcher", "test-writer", "code-reviewer", "code-simplifier"}
		var lines []string
		for _, name := range defaultAgents {
			lines = append(lines, dimStyle.Render(fmt.Sprintf("[ ] %s", name)))
		}
		return strings.Join(lines, "\n")
	}

	var lines []string
	for _, a := range agents {
		var line string
		name := fmt.Sprintf("%-15s", a.Name)

		switch a.Status {
		case "active":
			blink := blinkFrames[m.frame]
			line = runningStyle.Render(fmt.Sprintf("[%s] %s", blink, name))
		case "done":
			line = passedStyle.Render(fmt.Sprintf("[X] %s", name))
		default:
			line = dimStyle.Render(fmt.Sprintf("[ ] %s", name))
		}

		if a.Blockers > 0 {
			line += failedStyle.Render(fmt.Sprintf(" !%dB", a.Blockers))
		} else if a.Warnings > 0 {
			line += runningStyle.Render(fmt.Sprintf(" !%dW", a.Warnings))
		}

		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

func (m model) renderCommits() string {
	commits := m.status.Commits

	if len(commits) == 0 {
		return dimStyle.Render("< NO COMMITS YET >")
	}

	var lines []string
	// Show last 5 commits
	start := 0
	if len(commits) > 5 {
		start = len(commits) - 5
	}

	for _, c := range commits[start:] {
		hash := c.Hash
		if len(hash) > 7 {
			hash = hash[:7]
		}
		msg := c.Message
		if len(msg) > 35 {
			msg = msg[:32] + "..."
		}
		line := fmt.Sprintf("%s %s", passedStyle.Render(hash), textStyle.Render(msg))
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

// Helper functions
func stylePhase(phase string) string {
	switch phase {
	case "plan":
		return runningStyle.Render("● Planning")
	case "implement":
		return runningStyle.Render("● Implementing")
	case "review":
		return runningStyle.Render("● Reviewing")
	case "complete":
		return passedStyle.Render("✓ Complete")
	case "waiting", "STANDBY":
		return dimStyle.Render("○ Standby")
	default:
		return dimStyle.Render("○ " + phase)
	}
}

func styleStatus(status string) string {
	switch status {
	case "completed":
		return passedStyle.Render("Done")
	case "failed":
		return failedStyle.Render("Failed")
	case "in_progress":
		return runningStyle.Render("Running")
	default:
		return dimStyle.Render(status)
	}
}

func chunkIcon(status string) string {
	switch status {
	case "completed":
		return "●"
	case "failed":
		return "○"
	case "in_progress":
		return "◐"
	default:
		return "○"
	}
}

func gateIcon(status string) string {
	switch status {
	case "passed":
		return "✓"
	case "failed":
		return "✗"
	case "running":
		return "◐"
	case "skipped":
		return "−"
	default:
		return "○"
	}
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func main() {
	m := model{
		status: NewEmptyStatus(),
	}

	p := tea.NewProgram(m, tea.WithAltScreen())

	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
