#!/usr/bin/env bash
# evaluate-skills.sh — UserPromptSubmit hook
# Outputs skill evaluation instructions as additionalContext.
#
# Lists the skills available in .claude/skills/ so Claude knows what to invoke.
# Edit the BACKGROUND_SKILLS list below to match your project's skill directories.

SKILLS_DIR="$(dirname "$(dirname "$0")")/skills"
AVAILABLE_SKILLS=""

if [ -d "$SKILLS_DIR" ]; then
  AVAILABLE_SKILLS=$(ls "$SKILLS_DIR" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
fi

cat <<SKILLS_CONTEXT
## Skill Evaluation

Evaluate which skills are relevant to this task. For each YES skill, read its SKILL.md file — those rules override general conventions for their domain.

**Available skills:** ${AVAILABLE_SKILLS:-none configured}

Respond with \`Skills: [list]\` or \`Skills: none\`.
After skill evaluation, run knowledge preflight and read any canonical docs it routes you to under \`docs/knowledge/\` before editing.
SKILLS_CONTEXT
