#!/usr/bin/env bash
set -euo pipefail

GITHUB_USER="mikehins-fliip"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${GITHUB_USER}/dev-context-skill/main}"

SKILL_DIR="${HOME}/.claude/skills/dev-context"
TEMPLATES_DIR="${SKILL_DIR}/templates"

# Parse --ai flag: claude (default) | gemini | all
AI_TARGET="claude"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai) AI_TARGET="$2"; shift 2 ;;
    --ai=*) AI_TARGET="${1#--ai=}"; shift ;;
    *) shift ;;
  esac
done

if [[ "$AI_TARGET" != "claude" && "$AI_TARGET" != "gemini" && "$AI_TARGET" != "all" ]]; then
  echo "Error: --ai must be claude, gemini, or all" >&2
  exit 1
fi

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
echo "${INSTALL_MODE} dev-context skill (--ai ${AI_TARGET})..."

mkdir -p "${TEMPLATES_DIR}/decisions"

if [[ "${LOCAL_MODE}" == true ]]; then
  cp "${SCRIPT_DIR}/templates/CONTEXT.md.template"       "${TEMPLATES_DIR}/CONTEXT.md.template"
  cp "${SCRIPT_DIR}/templates/CURRENT.md.template"       "${TEMPLATES_DIR}/CURRENT.md.template"
  cp "${SCRIPT_DIR}/templates/CLAUDE.local.md.template"  "${TEMPLATES_DIR}/CLAUDE.local.md.template"
  cp "${SCRIPT_DIR}/templates/GEMINI.md.template"        "${TEMPLATES_DIR}/GEMINI.md.template"
  cp "${SCRIPT_DIR}/templates/dev-context.template"      "${TEMPLATES_DIR}/dev-context.template"
  cp "${SCRIPT_DIR}/templates/decisions/TEMPLATE.md"     "${TEMPLATES_DIR}/decisions/TEMPLATE.md"
else
  echo "Fetching templates from GitHub..."
  curl -fsSL "${BASE_URL}/templates/CONTEXT.md.template"       -o "${TEMPLATES_DIR}/CONTEXT.md.template"
  curl -fsSL "${BASE_URL}/templates/CURRENT.md.template"       -o "${TEMPLATES_DIR}/CURRENT.md.template"
  curl -fsSL "${BASE_URL}/templates/CLAUDE.local.md.template"  -o "${TEMPLATES_DIR}/CLAUDE.local.md.template"
  curl -fsSL "${BASE_URL}/templates/GEMINI.md.template"        -o "${TEMPLATES_DIR}/GEMINI.md.template"
  curl -fsSL "${BASE_URL}/templates/dev-context.template"      -o "${TEMPLATES_DIR}/dev-context.template"
  curl -fsSL "${BASE_URL}/templates/decisions/TEMPLATE.md"     -o "${TEMPLATES_DIR}/decisions/TEMPLATE.md"
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
   - Silently read ~/dev-context/[PROJECT_NAME]/CONTEXT.md
     (falls back to CLAUDE.md if CONTEXT.md does not exist — legacy naming)
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
- Never overwrite CONTEXT.md wholesale — only append to it
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
"I noticed we learned [short summary]. Want me to add this to CONTEXT.md? (yes / no / edit)"

- yes → append to the relevant section of ~/dev-context/[PROJECT_NAME]/CONTEXT.md
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
- A multi-step sequence kicked off by a ticket that repeated a familiar shape
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

**Step 5 — Push context to shared repo (if configured)**

Check if `.dev-context` exists at the repo root.

IF IT EXISTS:
- Read CONTEXT_REPO and CONTEXT_USER from the file (source it as shell vars)
- Run these commands exactly:

```bash
CONTEXT_DIR="$HOME/dev-context/[PROJECT_NAME]"
BRANCH="context/$CONTEXT_USER"

# Init git repo on first push
if [ ! -d "$CONTEXT_DIR/.git" ]; then
  git -C "$CONTEXT_DIR" init -b "$BRANCH"
  git -C "$CONTEXT_DIR" remote add origin "$CONTEXT_REPO"
fi

# Commit and push only if there are changes
git -C "$CONTEXT_DIR" add -A
if ! git -C "$CONTEXT_DIR" diff --cached --quiet; then
  git -C "$CONTEXT_DIR" commit -m "context: [PROJECT_NAME] $(date +%Y-%m-%d)"
  git -C "$CONTEXT_DIR" push origin "$BRANCH" --set-upstream
  echo "Context pushed to $CONTEXT_REPO on branch $BRANCH"
else
  echo "No context changes to push"
fi
```

IF IT DOES NOT EXIST:
- Skip silently — personal project or not yet configured

**Step 6 — Confirm**

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

# Configure Claude — appends to ~/.claude/CLAUDE.md
configure_claude() {
  local CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
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
}

# Configure Gemini — appends self-contained instructions to ~/.gemini/GEMINI.md
configure_gemini() {
  local GEMINI_MD="${HOME}/.gemini/GEMINI.md"
  mkdir -p "${HOME}/.gemini"
  if grep -q "dev-context/CONTEXT.md" "${GEMINI_MD}" 2>/dev/null; then
    echo "~/.gemini/GEMINI.md already contains dev-context block — skipping"
  else
    if [[ -f "${GEMINI_MD}" ]]; then
      cp "${GEMINI_MD}" "${GEMINI_MD}.bak"
      echo "Backed up ${GEMINI_MD} → ${GEMINI_MD}.bak"
    fi
    cat >> "${GEMINI_MD}" << 'GEMINIEOF'

---

## Dev-Context

Maintain a personal knowledge system at ~/dev-context/[PROJECT_NAME]/ for every project.
Templates are in ~/.claude/skills/dev-context/templates/.

**Session start — always do this first:**

1. Detect PROJECT_NAME from the current repo folder name.
   If the folder name is generic (src, app, code, project, repo), ask the user to confirm.

2. If ~/dev-context/[PROJECT_NAME]/ exists:
   - Silently read ~/dev-context/[PROJECT_NAME]/CONTEXT.md and CURRENT.md
   - Greet with one line: "Picking up from [last updated date]: [one sentence summary]."
   If it does not exist:
   - Create the folder from ~/.claude/skills/dev-context/templates/
   - Replace [PROJECT_NAME] in all template files with the actual project name
   - Tell the user: "I've created your dev-context folder at ~/dev-context/[PROJECT_NAME]/. Starting fresh!"

3. If GEMINI.md does not exist at the repo root:
   - Ask: "No GEMINI.md found here. Create one? (yes / skip)"
   - yes → create from ~/.claude/skills/dev-context/templates/GEMINI.md.template,
            replacing [PROJECT_NAME] with the actual project name

**Session end — triggered by "wrap up" or "update context":**

1. Rewrite ~/dev-context/[PROJECT_NAME]/CURRENT.md using CURRENT.md.template.
   Replace [DATE] with today's date in YYYY-MM-DD format. No placeholders left.

2. Ask: "I noticed we learned [short summary]. Want me to add this to CONTEXT.md? (yes / no / edit)"
   - yes/edit → append to ~/dev-context/[PROJECT_NAME]/CONTEXT.md

3. Ask: "Should I log the [topic] decision in decisions/[area].md? (yes / no)"
   - yes → append to ~/dev-context/[PROJECT_NAME]/decisions/[area].md
            Create from decisions template if it doesn't exist yet

4. Ask: "I think [pattern] could become a skill. Worth noting? (yes / no / later)"
   - yes/later → append to ~/dev-context/[PROJECT_NAME]/skill-candidates.md

5. Check if `.dev-context` exists at the repo root.
   IF IT EXISTS: read CONTEXT_REPO and CONTEXT_USER, then run:
   ```bash
   CONTEXT_DIR="$HOME/dev-context/[PROJECT_NAME]"
   BRANCH="context/$CONTEXT_USER"
   if [ ! -d "$CONTEXT_DIR/.git" ]; then
     git -C "$CONTEXT_DIR" init -b "$BRANCH"
     git -C "$CONTEXT_DIR" remote add origin "$CONTEXT_REPO"
   fi
   git -C "$CONTEXT_DIR" add -A
   if ! git -C "$CONTEXT_DIR" diff --cached --quiet; then
     git -C "$CONTEXT_DIR" commit -m "context: [PROJECT_NAME] $(date +%Y-%m-%d)"
     git -C "$CONTEXT_DIR" push origin "$BRANCH" --set-upstream
   fi
   ```
   IF IT DOES NOT EXIST: skip silently.

6. Print: "Context updated. See you next session. 👋"

**General rules:**
- Never mention reading context files out loud — summarize in one line
- Never overwrite CONTEXT.md wholesale — only append
- Never invent entries — only log things that actually came up
- Keep CURRENT.md honest and specific — vague entries are useless to future-you
GEMINIEOF
    echo "Appended dev-context block to ${GEMINI_MD}"
  fi
}

case "$AI_TARGET" in
  claude) configure_claude ;;
  gemini) configure_gemini ;;
  all)    configure_claude; configure_gemini ;;
esac

echo ""
echo "Done. Files written:"
echo "  ${SKILL_DIR}/SKILL.md"
echo "  ${SKILL_DIR}/wrap-up.md"
echo "  ${HOME}/.claude/skills/wrap-up/SKILL.md → (symlink)"
echo "  ${TEMPLATES_DIR}/CONTEXT.md.template"
echo "  ${TEMPLATES_DIR}/CURRENT.md.template"
echo "  ${TEMPLATES_DIR}/CLAUDE.local.md.template"
echo "  ${TEMPLATES_DIR}/GEMINI.md.template"
echo "  ${TEMPLATES_DIR}/dev-context.template"
echo "  ${TEMPLATES_DIR}/decisions/TEMPLATE.md"
echo ""
echo "Tip: inspect the script before running via curl: curl -fsSL ${BASE_URL}/install.sh | less"
