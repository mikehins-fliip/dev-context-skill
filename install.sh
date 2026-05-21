#!/usr/bin/env bash
set -euo pipefail

GITHUB_USER="mikehins-fliip"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${GITHUB_USER}/dev-context-skill/main}"

SKILL_DIR="${HOME}/.claude/skills/dev-context"
TEMPLATES_DIR="${SKILL_DIR}/templates"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"

# Detect local vs remote mode.
# When piped through bash (curl | bash), BASH_SOURCE[0] is empty or "-".
# When run as a file, BASH_SOURCE[0] is the script path and templates/ sits beside it.
if [[ -f "${BASH_SOURCE[0]:-}" ]] && [[ -d "$(dirname "${BASH_SOURCE[0]}")/templates" ]]; then
  LOCAL_MODE=true
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  LOCAL_MODE=false
fi

if [[ -d "${SKILL_DIR}" ]]; then
  INSTALL_MODE="Updating"
else
  INSTALL_MODE="Installing"
fi
echo "${INSTALL_MODE} dev-context skill..."

mkdir -p "${TEMPLATES_DIR}/decisions"

if [[ "${LOCAL_MODE}" == true ]]; then
  cp "${SCRIPT_DIR}/templates/CLAUDE.md.template"       "${TEMPLATES_DIR}/CLAUDE.md.template"
  cp "${SCRIPT_DIR}/templates/CURRENT.md.template"      "${TEMPLATES_DIR}/CURRENT.md.template"
  cp "${SCRIPT_DIR}/templates/CLAUDE.local.md.template" "${TEMPLATES_DIR}/CLAUDE.local.md.template"
  cp "${SCRIPT_DIR}/templates/decisions/TEMPLATE.md"    "${TEMPLATES_DIR}/decisions/TEMPLATE.md"
else
  echo "Fetching templates from GitHub..."
  curl -fsSL "${BASE_URL}/templates/CLAUDE.md.template"       -o "${TEMPLATES_DIR}/CLAUDE.md.template"
  curl -fsSL "${BASE_URL}/templates/CURRENT.md.template"      -o "${TEMPLATES_DIR}/CURRENT.md.template"
  curl -fsSL "${BASE_URL}/templates/CLAUDE.local.md.template" -o "${TEMPLATES_DIR}/CLAUDE.local.md.template"
  curl -fsSL "${BASE_URL}/templates/decisions/TEMPLATE.md"    -o "${TEMPLATES_DIR}/decisions/TEMPLATE.md"
fi

cat > "${SKILL_DIR}/SKILL.md" << 'SKILLEOF'
# Dev-Context Skill

Maintain a personal knowledge system at ~/dev-context/[PROJECT_NAME]/ for every project.
Templates for all files are in ~/.claude/skills/dev-context/templates/.

---

## Session Start — always do this first

1. Detect PROJECT_NAME from the current repo folder name
   (e.g. working in ~/code/myapp → PROJECT_NAME is "myapp")
   If the folder name is generic (src, app, code, project, repo) or ambiguous, ask the user to confirm.

2. Check if ~/dev-context/[PROJECT_NAME]/ exists.

   IF IT DOES NOT EXIST:
   - Create the folder structure using the templates in ~/.claude/skills/dev-context/templates/
   - Replace all occurrences of [PROJECT_NAME] in the templates with the actual project name
   - Tell the user:
     "I've created your dev-context folder at ~/dev-context/[PROJECT_NAME]/. Starting fresh!"

   IF IT EXISTS:
   - Silently read ~/dev-context/[PROJECT_NAME]/CLAUDE.md
   - Silently read ~/dev-context/[PROJECT_NAME]/CURRENT.md
   - Greet the user with one line:
     "Picking up from [last updated date]: [one sentence summary of current work and next step]."

3. Check if CLAUDE.local.md exists at the repo root.
   IF IT DOES NOT EXIST:
   - Ask: "No CLAUDE.local.md found here. Create one? (yes / skip)"
   - yes → create from ~/.claude/skills/dev-context/templates/CLAUDE.local.md.template,
            replacing [PROJECT_NAME] with the actual project name
   - skip → do nothing

---

## Session End

Triggered by: "wrap up", "/wrap-up", or "update context".
Read ~/.claude/skills/dev-context/wrap-up.md in full and execute every step.

---

## General behaviour rules

- Never mention reading context files out loud — do it silently, summarize in one line
- Never overwrite CLAUDE.md wholesale — only append to it
- Never invent entries — only log things that actually came up in the session
- Keep CURRENT.md entries honest and specific — vague entries are useless to future-you
- If unsure which decisions/ file to write to, ask the user before creating a new one
SKILLEOF

cat > "${SKILL_DIR}/wrap-up.md" << 'WRAPEOF'
# Wrap-Up Skill

Triggered by: "wrap up", "/wrap-up", or "update context"

Use PROJECT_NAME from the current session if already set by dev-context.
If running standalone, detect from the current repo folder name.
If the folder name is generic (src, app, code, project, repo), ask the user to confirm.

---

**Step 1 — Rewrite CURRENT.md**

Overwrite ~/dev-context/[PROJECT_NAME]/CURRENT.md with a fresh summary of this session.
Use the template at ~/.claude/skills/dev-context/templates/CURRENT.md.template.
Fill every section based on what actually happened. Do not leave placeholders.
Replace [DATE] with today's date in YYYY-MM-DD format.

**Step 2 — Check for domain discoveries**

Review the session for anything learned about:
- How the system works that wasn't obvious from the code
- A gotcha, edge case, or dangerous area
- Why something was built a certain way

If anything qualifies, ask:
"I noticed we learned [short summary]. Want me to add this to CLAUDE.md? (yes / no / edit)"

- yes → append to the relevant section of ~/dev-context/[PROJECT_NAME]/CLAUDE.md
- edit → let the user dictate exact wording, then append
- no → skip

**Step 3 — Check for decision log entries**

If a significant "why" was uncovered (business rule, historical reason, deliberate tradeoff), ask:
"Should I log the [topic] decision in decisions/[area].md? (yes / no)"

- yes → append a new entry to ~/dev-context/[PROJECT_NAME]/decisions/[area].md
         Create the file from the decisions template if it doesn't exist yet
- no → skip

**Step 4 — Check for skill candidates**

Review the session for any workflow patterns that were repetitive, manual, or could be
templated — things where a skill would have saved time or reduced back-and-forth.

Examples to look for:
- A multi-step sequence kicked off by a Jira ticket that repeated a familiar shape
- Boilerplate that had to be explained or reconstructed from scratch
- A prompt pattern used more than once to get the right output
- Something that took several exchanges to set up that could have been a single /command

If anything qualifies, ask:
"I think [short description of the pattern] could become a skill. Worth noting? (yes / no / later)"

- yes → create or append to ~/dev-context/[PROJECT_NAME]/skill-candidates.md with:
  - Date
  - What the pattern was
  - Why it felt repetitive or manual
  - A rough sketch of what the skill would do
- later → add a one-line note to skill-candidates.md marked as [low priority]
- no → skip

If skill-candidates.md doesn't exist yet, create it with this header:

```
# Skill Candidates — [PROJECT_NAME]

Patterns spotted during wrap-up that might be worth turning into skills.
Review occasionally and promote to ~/.claude/skills/ when a pattern repeats enough to justify it.
```

**Step 5 — Confirm**

Print: "Context updated. See you next session. 👋"
WRAPEOF

# Symlink wrap-up skill → dev-context/wrap-up.md (single source of truth)
mkdir -p "${HOME}/.claude/skills/wrap-up"
if [[ -L "${HOME}/.claude/skills/wrap-up/SKILL.md" ]]; then
  SYMLINK_STATUS="updated"
else
  SYMLINK_STATUS="created"
fi
ln -sf "${SKILL_DIR}/wrap-up.md" "${HOME}/.claude/skills/wrap-up/SKILL.md"
echo "Symlink ${SYMLINK_STATUS}: ~/.claude/skills/wrap-up/SKILL.md → wrap-up.md"

# Append dev-context block to ~/.claude/CLAUDE.md (idempotent)
if grep -q "dev-context/SKILL.md" "${CLAUDE_MD}" 2>/dev/null; then
  echo "~/.claude/CLAUDE.md already contains dev-context block — skipping"
else
  if [[ -f "${CLAUDE_MD}" ]]; then
    cp "${CLAUDE_MD}" "${CLAUDE_MD}.bak"
    echo "Backed up ${CLAUDE_MD} → ${CLAUDE_MD}.bak"
  fi
  cat >> "${CLAUDE_MD}" << 'CLAUDEEOF'

---

## Dev-Context Skill

I maintain a personal knowledge system for every project.
Full instructions are in ~/.claude/skills/dev-context/SKILL.md — read it at the start of every session.
CLAUDEEOF
  echo "Appended dev-context block to ${CLAUDE_MD}"
fi

echo ""
echo "Done. Files written:"
echo "  ${SKILL_DIR}/SKILL.md"
echo "  ${SKILL_DIR}/wrap-up.md"
echo "  ${HOME}/.claude/skills/wrap-up/SKILL.md → (symlink)"
echo "  ${TEMPLATES_DIR}/CLAUDE.md.template"
echo "  ${TEMPLATES_DIR}/CURRENT.md.template"
echo "  ${TEMPLATES_DIR}/CLAUDE.local.md.template"
echo "  ${TEMPLATES_DIR}/decisions/TEMPLATE.md"
echo ""
echo "Tip: inspect the script before running via curl: curl -fsSL ${BASE_URL}/install.sh | less"
