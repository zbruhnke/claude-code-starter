# Agents - Specialized Subagents

Agents are focused AI assistants with limited tool access. They're useful for delegating specific tasks while maintaining control over what capabilities are available.

## Agent File Format

Agents use YAML frontmatter followed by instructions:

```markdown
---
name: researcher
description: Explore and understand codebases without making changes
tools: Read, Grep, Glob, WebSearch, WebFetch
model: sonnet
---

You are a research assistant. Your job is to understand code, not change it.

When asked to research:
1. Start broad - understand the overall structure
2. Find relevant files using Grep and Glob
3. Read and understand the code
4. Explain clearly with file:line references

Never suggest changes. Only explain what exists.
```

## Available Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Identifier for the agent |
| `description` | Yes | When to use this agent |
| `tools` | Yes | Comma-separated list of allowed tools |
| `model` | Yes | `sonnet` (fast), `opus` (thorough), `haiku` (quick tasks) |

## Using Agents

Invoke agents by name in your request:

```
Use the researcher agent to understand how authentication works

Use the code-reviewer agent to review my changes to the payment module

Use the test-writer agent to generate tests for the UserService class
```

## Included Agents

| Agent | Purpose | Tools | Model |
|-------|---------|-------|-------|
| `researcher` | Read-only exploration | Read, Grep, Glob, WebSearch, WebFetch | sonnet |
| `code-reviewer` | Thorough code review | Read, Grep, Glob (read-only) | opus |
| `test-writer` | Generate comprehensive tests | Read, Grep, Glob, Edit, Write, Bash | opus |

## Creating Your Own Agent

1. Create file: `.claude/agents/my-agent.md`
2. Add YAML frontmatter with required fields
3. Write instructions below the frontmatter

### Example: Documentation Agent

```markdown
---
name: doc-writer
description: Generate documentation for code
tools: Read, Grep, Glob, Write
model: sonnet
---

You are a documentation specialist. When asked to document code:

1. Read the code thoroughly
2. Identify public APIs, classes, and functions
3. Generate clear, concise documentation
4. Include:
   - Purpose and usage
   - Parameters and return values
   - Examples where helpful
   - Edge cases and limitations

Write documentation in the project's existing style. If no style exists, use JSDoc/docstrings appropriate to the language.
```

## Agent vs Skill

| Aspect | Skill | Agent |
|--------|-------|-------|
| Purpose | Specific task with defined output | Flexible assistant for a domain |
| Invocation | Semantic matching from description | Explicit "use X agent" request |
| Scope | Single focused task | Broader, multi-step work |
| Tools | Task-specific subset | Domain-appropriate subset |

**Use skills** for repeatable tasks with consistent output (code review, test generation).

**Use agents** for exploratory work or tasks that need judgment (research, documentation).

## Tips

- Limit tools to only what the agent needs
- Use `sonnet` for read-only agents (faster, cheaper)
- Use `opus` for agents that need deep reasoning
- Be explicit about what the agent should NOT do
- Include output format preferences in instructions
