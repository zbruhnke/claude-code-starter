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

	var b strings.Builder

	// Soft header separator
	separator := strings.Repeat("─", m.width)
	b.WriteString(dimStyle.Render(separator))
	b.WriteString("\n")

	// Title bar
	title := titleStyle.Render(" ✦ WIGGUM DASHBOARD ✦ ")
	timestamp := dimStyle.Render(fmt.Sprintf("⏱ %s", time.Now().Format("15:04:05")))
	padding := strings.Repeat(" ", max(0, m.width-lipgloss.Width(title)-lipgloss.Width(timestamp)-2))
	b.WriteString(title + padding + timestamp)
	b.WriteString("\n")

	b.WriteString(dimStyle.Render(separator))
	b.WriteString("\n")

	// Stop condition banner (if active)
	if m.status.StopConditions.Active {
		b.WriteString("\n")
		banner := m.renderStopBanner()
		b.WriteString(banner)
		b.WriteString("\n")
	}

	b.WriteString("\n")

	// Error/waiting display
	if m.err != nil {
		blink := blinkFrames[m.frame]
		b.WriteString(runningStyle.Render(fmt.Sprintf(" %s Awaiting session... %s", blink, blink)))
		b.WriteString("\n")
		b.WriteString(dimStyle.Render(fmt.Sprintf("   [%v]", m.err)))
		b.WriteString("\n\n")
	}

	// Main content in columns
	leftCol := m.renderLeftColumn()
	rightCol := m.renderRightColumn()

	// Calculate column widths
	leftWidth := m.width/2 - 2
	rightWidth := m.width/2 - 2

	leftCol = lipgloss.NewStyle().Width(leftWidth).Render(leftCol)
	rightCol = lipgloss.NewStyle().Width(rightWidth).Render(rightCol)

	columns := lipgloss.JoinHorizontal(lipgloss.Top, leftCol, "  ", rightCol)
	b.WriteString(columns)

	// Footer
	b.WriteString("\n\n")
	b.WriteString(dimStyle.Render(separator))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render(" [Q] Quit  [R] Refresh                    "))
	status := "● Monitoring"
	if m.status.StopConditions.Active {
		status = "!! STOPPED"
	} else if m.status.Session.Phase == "complete" {
		status = "✓ Complete"
	} else if m.err != nil {
		status = "○ Standby"
	}

	if m.status.StopConditions.Active {
		b.WriteString(failedStyle.Render(status))
	} else {
		b.WriteString(textStyle.Render(status))
	}

	return b.String()
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

func (m model) renderLeftColumn() string {
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

	// Current Task
	b.WriteString(headerStyle.Render("◈ Active Task"))
	b.WriteString("\n")
	taskContent := m.renderCurrentTask()
	style := boxStyle
	if m.status.CurrentTask.Status == "in_progress" {
		style = activeBoxStyle
	}
	b.WriteString(style.Render(taskContent))
	b.WriteString("\n\n")

	// Chunks
	b.WriteString(headerStyle.Render("◈ Chunks"))
	b.WriteString("\n")
	chunksContent := m.renderChunks()
	b.WriteString(boxStyle.Render(chunksContent))

	return b.String()
}

func (m model) renderRightColumn() string {
	var b strings.Builder

	// Gates
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

	// Commits
	b.WriteString(headerStyle.Render("◈ Commits"))
	b.WriteString("\n")
	commitsContent := m.renderCommits()
	b.WriteString(boxStyle.Render(commitsContent))

	return b.String()
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
