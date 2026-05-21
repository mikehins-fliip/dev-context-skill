# dev-context-skill

A personal knowledge system for any AI coding assistant — Claude Code, Gemini, or both.

Maintains context at `~/dev-context/[project]/` — outside your repo,
invisible to git, always available to your AI assistant.

## What it does

**Session start:** AI silently reads your context files and picks up where you left off.

**`/wrap-up`:** Updates your notes, logs domain discoveries, flags decision log entries,
and spots workflow patterns worth automating.

## Install

**Claude Code (default):**

```bash
curl -fsSL https://raw.githubusercontent.com/mikehins-fliip/dev-context-skill/main/install.sh | bash
```

**Gemini:**

```bash
curl -fsSL https://raw.githubusercontent.com/mikehins-fliip/dev-context-skill/main/install.sh | bash -s -- --ai gemini
```

**Both:**

```bash
curl -fsSL https://raw.githubusercontent.com/mikehins-fliip/dev-context-skill/main/install.sh | bash -s -- --ai all
```

> Prefer to inspect first? `curl -fsSL https://raw.githubusercontent.com/mikehins-fliip/dev-context-skill/main/install.sh | less`

Or clone and run locally:

```bash
git clone https://github.com/mikehins-fliip/dev-context-skill.git
bash dev-context-skill/install.sh --ai all
```

## What gets installed

```
~/.claude/
├── CLAUDE.md              ← block appended (idempotent, backed up first)
└── skills/
    └── dev-context/
        ├── SKILL.md
        ├── wrap-up.md
        └── templates/
            ├── CONTEXT.md.template
            ├── CURRENT.md.template
            ├── CLAUDE.local.md.template
            ├── GEMINI.md.template
            └── decisions/
                └── TEMPLATE.md

~/.gemini/
└── GEMINI.md              ← block appended (--ai gemini or --ai all only)
```

Per-project knowledge lives in `~/dev-context/[project]/` and is created automatically
on your first session in any repo. Both assistants read the same files.

## Knowledge files

### `CONTEXT.md` — what the AI can't infer from the code

Things that look wrong but are intentional, dangerous areas, and hard-won lessons.
Appended to during `/wrap-up` when something worth keeping surfaces.

```markdown
## Domain Rules That Aren't Obvious
- All prices are stored in cents (integer), never floats. The `formatPrice()` helper
  handles display. Passing a float anywhere in the billing pipeline causes silent
  rounding errors that only show up on edge amounts like $0.10.

## Dangerous Areas
- `jobs/ProcessRefund.php` retries up to 5 times with no dedup guard. A bug in the
  job handler can trigger multiple refunds for the same transaction.
  Always test with --dry-run before any change here.

## What I've Learned the Hard Way
- `users.organization_id` is NOT the source of truth for org membership.
  Use the `organization_members` join table — users can belong to multiple orgs
  and `organization_id` may be stale after a transfer.
```

**How the AI uses it:** If you ask "can I refactor the billing flow?", it already knows
about the integer-only price rule and the refund retry risk — without you explaining it again.

---

### `CURRENT.md` — re-entry note for next session

Written at `/wrap-up`. Tells the AI exactly where things stand so the next session
starts at full speed.

```markdown
## Last updated
2026-05-20

## What I'm working on
PROJ-412 — migrating report exports to async queue

## What's actually done
- Queue job class created, dispatches correctly in local
- Migration written (not yet run in any environment)

## What's open / unresolved
- Need to confirm max export row limit before setting chunk size
- Email notification template not started

## Next concrete step
Wire up the failure handler — on job failure, notify the user via email

## Watch out for
- `exports` table has a composite unique index on (org_id, created_at).
  Bulk inserts will silently fail if two exports land within the same second.
```

**How the AI uses it:** Session opens with: *"Picking up from 2026-05-20: async report
export (PROJ-412) — job dispatches, migration pending, next step is the failure handler."*

---

### `decisions/[area].md` — why things are the way they are

One file per domain area. Append-only log of decisions, tradeoffs, and historical context.
Prompted during `/wrap-up` when a significant "why" surfaces.

```markdown
# Decision Log — Payments

### 2026-04-10 — Kept payment charge synchronous in checkout

**Context:** Explored moving the charge call to a background job to speed up checkout.

**What we found:** The payment provider's idempotency key TTL is 24h. If a queued job
retries after expiry, a duplicate charge is issued with no server-side way to detect it.

**Why it is the way it is:** Synchronous is slower but safe. Async would require a custom
dedup layer we don't have bandwidth to build right now.

**What breaks if you ignore this:** Duplicate charges during retry storms.

**Related:** PROJ-201, payment provider idempotency docs.
```

**How the AI uses it:** When you revisit checkout months later, it knows the async
path was already explored and why it was rejected — no re-investigation needed.

---

### `skill-candidates.md` — patterns worth automating

Surfaces during `/wrap-up` when the AI spots something repetitive or manual.

```markdown
# Skill Candidates — myapp

### 2026-05-18 — Ticket → migration → test scaffold
Every bug fix follows the same shape: fetch ticket → read AC → write migration →
write unit test → update CURRENT.md. Took 4+ exchanges to set up each time.
Rough skill: given a ticket number, scaffold migration + test stubs in one shot.
```

---

## AI compatibility

| Feature | Claude Code | Gemini |
|---|---|---|
| Session start (auto-load context) | ✅ via skill | ✅ via GEMINI.md |
| `/wrap-up` slash command | ✅ | ❌ — use phrase "wrap up" |
| Shared `~/dev-context/` knowledge | ✅ | ✅ |
| Repo-root config file | `CLAUDE.local.md` | `GEMINI.md` |

---

## Roadmap

- [ ] Two-layer system — shared `docs-context/` folder in repo read alongside personal context
- [ ] `/wrap-up` promotion flow — offer to stage personal discoveries for team review
- [ ] Weekly distill command — AI reads recent merged PRs + personal context files,
      proposes a shared update PR against the testing branch
- [ ] Team install guide — onboard a whole repo with one command

## To update

Re-run the install command — `SKILL.md`, `wrap-up.md`, and all templates are overwritten.
Config file blocks are skipped if already present (no duplicates).

## Uninstall

```bash
rm -rf ~/.claude/skills/dev-context/ ~/.claude/skills/wrap-up/
```

Then remove the `## Dev-Context Skill` block from `~/.claude/CLAUDE.md`
and the `## Dev-Context` block from `~/.gemini/GEMINI.md` if applicable.
