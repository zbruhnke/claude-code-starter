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

// Retro CRT color palette
var (
	phosphorGreen = lipgloss.Color("46")  // Bright green
	dimGreen      = lipgloss.Color("28")  // Dim green
	amberColor    = lipgloss.Color("214") // Amber/orange
	alertRed      = lipgloss.Color("196") // Red for errors
	crtBackground = lipgloss.Color("16")  // Near black

	// Styles
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("16")).
			Background(phosphorGreen).
			Padding(0, 1)

	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(phosphorGreen).
			Underline(true)

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.Border{
			Top:         "─",
			Bottom:      "─",
			Left:        "│",
			Right:       "│",
			TopLeft:     "┌",
			TopRight:    "┐",
			BottomLeft:  "└",
			BottomRight: "┘",
		}).
		BorderForeground(dimGreen).
		Padding(0, 1)

	activeBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.Border{
			Top:         "═",
			Bottom:      "═",
			Left:        "║",
			Right:       "║",
			TopLeft:     "╔",
			TopRight:    "╗",
			BottomLeft:  "╚",
			BottomRight: "╝",
		}).
		BorderForeground(phosphorGreen).
		Padding(0, 1)

	passedStyle = lipgloss.NewStyle().
			Foreground(phosphorGreen).
			Bold(true)

	failedStyle = lipgloss.NewStyle().
			Foreground(alertRed).
			Bold(true)

	pendingStyle = lipgloss.NewStyle().
			Foreground(dimGreen)

	runningStyle = lipgloss.NewStyle().
			Foreground(amberColor).
			Bold(true)

	textStyle = lipgloss.NewStyle().
			Foreground(phosphorGreen)

	dimStyle = lipgloss.NewStyle().
			Foreground(dimGreen)

	blinkFrames = []string{"█", "▓", "▒", "░", "▒", "▓"}
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

	// Retro header with scanline effect
	scanline := strings.Repeat("▀", m.width)
	b.WriteString(dimStyle.Render(scanline))
	b.WriteString("\n")

	// Title bar
	title := titleStyle.Render(" ◄ WIGGUM COMMAND CENTER ► ")
	timestamp := dimStyle.Render(fmt.Sprintf("[%s]", time.Now().Format("15:04:05")))
	padding := strings.Repeat(" ", max(0, m.width-lipgloss.Width(title)-lipgloss.Width(timestamp)-2))
	b.WriteString(title + padding + timestamp)
	b.WriteString("\n")

	b.WriteString(dimStyle.Render(scanline))
	b.WriteString("\n\n")

	// Error/waiting display
	if m.err != nil {
		blink := blinkFrames[m.frame]
		b.WriteString(runningStyle.Render(fmt.Sprintf(" %s AWAITING SESSION... %s", blink, blink)))
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
	b.WriteString(dimStyle.Render(scanline))
	b.WriteString("\n")
	b.WriteString(dimStyle.Render(" [Q]UIT  [R]EFRESH                    "))
	status := "MONITORING"
	if m.status.Session.Phase == "complete" {
		status = "SESSION COMPLETE"
	} else if m.err != nil {
		status = "STANDBY"
	}
	b.WriteString(textStyle.Render(fmt.Sprintf("STATUS: %s", status)))

	return b.String()
}

func (m model) renderLeftColumn() string {
	var b strings.Builder

	// Session Info
	b.WriteString(headerStyle.Render("■ SESSION DATA"))
	b.WriteString("\n")
	sessionContent := m.renderSessionInfo()
	b.WriteString(boxStyle.Render(sessionContent))
	b.WriteString("\n\n")

	// Current Task
	b.WriteString(headerStyle.Render("■ ACTIVE TASK"))
	b.WriteString("\n")
	taskContent := m.renderCurrentTask()
	style := boxStyle
	if m.status.CurrentTask.Status == "in_progress" {
		style = activeBoxStyle
	}
	b.WriteString(style.Render(taskContent))
	b.WriteString("\n\n")

	// Chunks
	b.WriteString(headerStyle.Render("■ CHUNK PROGRESS"))
	b.WriteString("\n")
	chunksContent := m.renderChunks()
	b.WriteString(boxStyle.Render(chunksContent))

	return b.String()
}

func (m model) renderRightColumn() string {
	var b strings.Builder

	// Gates
	b.WriteString(headerStyle.Render("■ COMMAND GATES"))
	b.WriteString("\n")
	gatesContent := m.renderGates()
	b.WriteString(boxStyle.Render(gatesContent))
	b.WriteString("\n\n")

	// Agents
	b.WriteString(headerStyle.Render("■ AGENT STATUS"))
	b.WriteString("\n")
	agentsContent := m.renderAgents()
	b.WriteString(boxStyle.Render(agentsContent))
	b.WriteString("\n\n")

	// Commits
	b.WriteString(headerStyle.Render("■ GIT LOG"))
	b.WriteString("\n")
	commitsContent := m.renderCommits()
	b.WriteString(boxStyle.Render(commitsContent))

	return b.String()
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

		var line string
		switch c.Status {
		case "completed":
			line = passedStyle.Render(fmt.Sprintf("%s [%s] %s", icon, num, c.Name))
		case "in_progress":
			blink := blinkFrames[m.frame]
			line = runningStyle.Render(fmt.Sprintf("%s [%s] %s %s", icon, num, c.Name, blink))
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

	gates := []struct {
		name   string
		result GateResult
	}{
		{"TEST", g.Test},
		{"LINT", g.Lint},
		{"TYPECHECK", g.TypeCheck},
		{"BUILD", g.Build},
		{"FORMAT", g.Format},
	}

	var lines []string
	for _, gate := range gates {
		icon := gateIcon(gate.result.Status)
		cmd := gate.result.Command
		if cmd == "" {
			cmd = "---"
		}
		if len(cmd) > 18 {
			cmd = cmd[:15] + "..."
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
		return runningStyle.Render("▶ PLANNING")
	case "implement":
		return runningStyle.Render("▶ IMPLEMENTING")
	case "review":
		return runningStyle.Render("▶ REVIEWING")
	case "complete":
		return passedStyle.Render("■ COMPLETE")
	case "waiting", "STANDBY":
		return dimStyle.Render("○ STANDBY")
	default:
		return dimStyle.Render("○ " + strings.ToUpper(phase))
	}
}

func styleStatus(status string) string {
	switch status {
	case "completed":
		return passedStyle.Render("DONE")
	case "failed":
		return failedStyle.Render("FAIL")
	case "in_progress":
		return runningStyle.Render("RUNNING")
	default:
		return dimStyle.Render(strings.ToUpper(status))
	}
}

func chunkIcon(status string) string {
	switch status {
	case "completed":
		return "■"
	case "failed":
		return "✗"
	case "in_progress":
		return "▶"
	default:
		return "□"
	}
}

func gateIcon(status string) string {
	switch status {
	case "passed":
		return "[✓]"
	case "failed":
		return "[✗]"
	case "running":
		return "[~]"
	case "skipped":
		return "[-]"
	default:
		return "[ ]"
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
