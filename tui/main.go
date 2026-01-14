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

// Styles
var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("229")).
			Background(lipgloss.Color("57")).
			Padding(0, 1)

	headerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("212"))

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("240")).
			Padding(0, 1)

	activeBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("212")).
			Padding(0, 1)

	passedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("82"))

	failedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("196"))

	pendingStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("243"))

	runningStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("214"))

	dimStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("243"))
)

type model struct {
	status     *WiggumStatus
	err        error
	width      int
	height     int
	lastUpdate time.Time
}

type tickMsg time.Time
type statusMsg *WiggumStatus
type errMsg error

func tick() tea.Cmd {
	return tea.Tick(time.Second, func(t time.Time) tea.Msg {
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
		return "Loading..."
	}

	var b strings.Builder

	// Title bar
	title := titleStyle.Render(" 🚔 WIGGUM DASHBOARD ")
	b.WriteString(title)
	b.WriteString("\n\n")

	// Error display
	if m.err != nil {
		b.WriteString(dimStyle.Render(fmt.Sprintf("Waiting for session... (%v)", m.err)))
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
	b.WriteString(dimStyle.Render("Press 'q' to quit, 'r' to refresh"))

	return b.String()
}

func (m model) renderLeftColumn() string {
	var b strings.Builder

	// Session Info
	b.WriteString(headerStyle.Render("SESSION"))
	b.WriteString("\n")
	sessionContent := m.renderSessionInfo()
	b.WriteString(boxStyle.Render(sessionContent))
	b.WriteString("\n\n")

	// Current Task
	b.WriteString(headerStyle.Render("CURRENT TASK"))
	b.WriteString("\n")
	taskContent := m.renderCurrentTask()
	style := boxStyle
	if m.status.CurrentTask.Status == "in_progress" {
		style = activeBoxStyle
	}
	b.WriteString(style.Render(taskContent))
	b.WriteString("\n\n")

	// Chunks
	b.WriteString(headerStyle.Render("CHUNKS"))
	b.WriteString("\n")
	chunksContent := m.renderChunks()
	b.WriteString(boxStyle.Render(chunksContent))

	return b.String()
}

func (m model) renderRightColumn() string {
	var b strings.Builder

	// Gates
	b.WriteString(headerStyle.Render("COMMAND GATES"))
	b.WriteString("\n")
	gatesContent := m.renderGates()
	b.WriteString(boxStyle.Render(gatesContent))
	b.WriteString("\n\n")

	// Agents
	b.WriteString(headerStyle.Render("AGENTS"))
	b.WriteString("\n")
	agentsContent := m.renderAgents()
	b.WriteString(boxStyle.Render(agentsContent))
	b.WriteString("\n\n")

	// Commits
	b.WriteString(headerStyle.Render("COMMITS"))
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
		phase = "waiting"
	}

	lines = append(lines, fmt.Sprintf("Phase:     %s", stylePhase(phase)))
	lines = append(lines, fmt.Sprintf("Iteration: %d/%d", s.Session.Iteration, s.Session.MaxIterations))

	if !s.Session.StartTime.IsZero() {
		elapsed := time.Since(s.Session.StartTime).Round(time.Second)
		lines = append(lines, fmt.Sprintf("Elapsed:   %s", elapsed))
	}

	if s.Session.StartCommit != "" {
		lines = append(lines, fmt.Sprintf("Start:     %s", s.Session.StartCommit[:7]))
	}

	return strings.Join(lines, "\n")
}

func (m model) renderCurrentTask() string {
	t := m.status.CurrentTask

	if t.Name == "" {
		return dimStyle.Render("No active task")
	}

	var lines []string
	lines = append(lines, fmt.Sprintf("%s", t.Name))
	if t.Description != "" {
		lines = append(lines, dimStyle.Render(t.Description))
	}
	lines = append(lines, fmt.Sprintf("Status: %s  Attempt: %d/%d",
		styleStatus(t.Status), t.Attempt, t.MaxAttempts))

	return strings.Join(lines, "\n")
}

func (m model) renderChunks() string {
	chunks := m.status.Chunks

	if len(chunks) == 0 {
		return dimStyle.Render("No chunks defined")
	}

	var lines []string
	for _, c := range chunks {
		icon := statusIcon(c.Status)
		line := fmt.Sprintf("%s %d. %s", icon, c.ID, c.Name)
		if c.Status == "in_progress" {
			line = runningStyle.Render(line)
		} else if c.Status == "completed" {
			line = passedStyle.Render(line)
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
			cmd = "-"
		}
		if len(cmd) > 20 {
			cmd = cmd[:17] + "..."
		}
		line := fmt.Sprintf("%s %-10s %s", icon, gate.name, dimStyle.Render(cmd))
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
			lines = append(lines, fmt.Sprintf("○ %s", dimStyle.Render(name)))
		}
		return strings.Join(lines, "\n")
	}

	var lines []string
	for _, a := range agents {
		icon := "○"
		style := dimStyle
		if a.Status == "active" {
			icon = "●"
			style = runningStyle
		} else if a.Status == "done" {
			icon = "✓"
			style = passedStyle
		}

		line := fmt.Sprintf("%s %s", icon, a.Name)
		if a.Blockers > 0 {
			line += failedStyle.Render(fmt.Sprintf(" (%d blockers)", a.Blockers))
		} else if a.Warnings > 0 {
			line += runningStyle.Render(fmt.Sprintf(" (%d warnings)", a.Warnings))
		}
		lines = append(lines, style.Render(line))
	}

	return strings.Join(lines, "\n")
}

func (m model) renderCommits() string {
	commits := m.status.Commits

	if len(commits) == 0 {
		return dimStyle.Render("No commits yet")
	}

	var lines []string
	// Show last 5 commits
	start := 0
	if len(commits) > 5 {
		start = len(commits) - 5
	}

	for _, c := range commits[start:] {
		msg := c.Message
		if len(msg) > 40 {
			msg = msg[:37] + "..."
		}
		line := fmt.Sprintf("%s %s", passedStyle.Render(c.Hash[:7]), msg)
		lines = append(lines, line)
	}

	return strings.Join(lines, "\n")
}

// Helper functions
func stylePhase(phase string) string {
	switch phase {
	case "plan":
		return runningStyle.Render("PLAN")
	case "implement":
		return runningStyle.Render("IMPLEMENT")
	case "review":
		return runningStyle.Render("REVIEW")
	case "complete":
		return passedStyle.Render("COMPLETE")
	default:
		return pendingStyle.Render(strings.ToUpper(phase))
	}
}

func styleStatus(status string) string {
	switch status {
	case "completed":
		return passedStyle.Render("completed")
	case "failed":
		return failedStyle.Render("failed")
	case "in_progress":
		return runningStyle.Render("in progress")
	default:
		return pendingStyle.Render(status)
	}
}

func statusIcon(status string) string {
	switch status {
	case "completed":
		return passedStyle.Render("✓")
	case "failed":
		return failedStyle.Render("✗")
	case "in_progress":
		return runningStyle.Render("●")
	default:
		return pendingStyle.Render("○")
	}
}

func gateIcon(status string) string {
	switch status {
	case "passed":
		return passedStyle.Render("✓")
	case "failed":
		return failedStyle.Render("✗")
	case "running":
		return runningStyle.Render("●")
	case "skipped":
		return dimStyle.Render("-")
	default:
		return pendingStyle.Render("○")
	}
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
