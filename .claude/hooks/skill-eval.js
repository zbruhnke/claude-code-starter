#!/usr/bin/env node

/**
 * Skill Evaluation Hook
 *
 * Analyzes user prompts and suggests relevant skills based on:
 * - Keywords (2 points each)
 * - Keyword patterns (3 points each)
 * - Path patterns (4 points each)
 * - Intent patterns (4 points each)
 *
 * Outputs a skill suggestion if confidence exceeds threshold.
 */

const fs = require('fs');
const path = require('path');

// Configuration
const CONFIDENCE_THRESHOLD = 5; // Minimum score to suggest
const MAX_SUGGESTIONS = 2;

// Read skill rules
const rulesPath = path.join(__dirname, 'skill-rules.json');
let skillRules;

try {
  skillRules = JSON.parse(fs.readFileSync(rulesPath, 'utf8'));
} catch (err) {
  // No rules file, exit silently
  process.exit(0);
}

// Read input from stdin
let input = '';
process.stdin.setEncoding('utf8');

process.stdin.on('data', (chunk) => {
  input += chunk;
});

process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);

    // UserPromptSubmit hook receives the prompt in tool_input.prompt
    // Structure: { tool_name, tool_input: { prompt } }
    const prompt = data.tool_input?.prompt || data.prompt || '';

    if (!prompt) {
      process.exit(0);
    }

    const suggestions = evaluateSkills(prompt.toLowerCase());

    if (suggestions.length > 0) {
      const output = formatSuggestions(suggestions);
      // Output as JSON response with feedback field
      console.log(JSON.stringify({
        feedback: output,
        continue: true
      }));
    }

    process.exit(0);
  } catch (err) {
    // On error, allow the prompt to continue without suggestions
    process.exit(0);
  }
});

function evaluateSkills(prompt) {
  const scores = [];

  for (const [skillName, config] of Object.entries(skillRules)) {
    let score = 0;
    const matches = [];

    const triggers = config.triggers || {};

    // Check keywords (2 points each)
    for (const keyword of (triggers.keywords || [])) {
      if (prompt.includes(keyword.toLowerCase())) {
        score += 2;
        matches.push(`keyword "${keyword}"`);
      }
    }

    // Check keyword patterns (3 points each)
    for (const pattern of (triggers.keywordPatterns || [])) {
      try {
        const regex = new RegExp(pattern, 'i');
        if (regex.test(prompt)) {
          score += 3;
          matches.push(`pattern /${pattern}/`);
        }
      } catch (e) {
        // Invalid regex, skip
      }
    }

    // Check intent patterns (4 points each)
    for (const pattern of (triggers.intentPatterns || [])) {
      try {
        const regex = new RegExp(pattern, 'i');
        if (regex.test(prompt)) {
          score += 4;
          matches.push(`intent "${pattern.substring(0, 30)}..."`);
        }
      } catch (e) {
        // Invalid regex, skip
      }
    }

    // Path patterns would require file context, skip for now
    // Could be enhanced to check if prompt mentions file paths

    if (score >= CONFIDENCE_THRESHOLD) {
      scores.push({
        skill: skillName,
        score,
        priority: config.priority || 5,
        description: config.description,
        matches: matches.slice(0, 3) // Top 3 matches
      });
    }
  }

  // Sort by score * priority, descending
  scores.sort((a, b) => (b.score * b.priority) - (a.score * a.priority));

  return scores.slice(0, MAX_SUGGESTIONS);
}

function formatSuggestions(suggestions) {
  if (suggestions.length === 0) return '';

  const lines = ['Skill suggestions:'];

  for (const s of suggestions) {
    const confidence = Math.min(99, Math.round((s.score / 15) * 100));
    lines.push(`  /${s.skill} (${confidence}% match) - ${s.description}`);
    if (s.matches.length > 0) {
      lines.push(`    Matched: ${s.matches.join(', ')}`);
    }
  }

  lines.push('');
  lines.push('Invoke with: /<skill-name> or ignore to proceed normally.');

  return lines.join('\n');
}
