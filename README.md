# dev-context-skill

A Claude Code skill that reduces cognitive debt on any codebase.

Maintains a personal knowledge system at `~/dev-context/[project]/` — outside your repo,
invisible to git, always available to Claude Code.

## What it does

**Session start:** Claude silently reads your context files and picks up where you left off.

**`/wrap-up`:** Claude updates your notes, logs domain discoveries, flags decision log entries,
and spots workflow patterns worth turning into skills.

## Install

**One-liner (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/mikehins-fliip/dev-context-skill/main/install.sh | bash
```

> Prefer to inspect first? `curl -fsSL https://raw.githubusercontent.com/mikehins-fliip/dev-context-skill/main/install.sh | less`

Or clone and run locally:

```bash
git clone https://github.com/mikehins-fliip/dev-context-skill.git
bash dev-context-skill/install.sh
```

## What gets installed

```
~/.claude/
├── CLAUDE.md              ← 3 lines appended (idempotent, backed up first)
└── skills/
    └── dev-context/
        ├── SKILL.md
        └── templates/
            ├── CLAUDE.md.template
            ├── CURRENT.md.template
            ├── CLAUDE.local.md.template
            └── decisions/
                └── TEMPLATE.md
```

Per-project knowledge lives in `~/dev-context/[project]/` and is created automatically
on your first Claude Code session in any repo.

## Knowledge files

### `CLAUDE.md` — what Claude can't infer from the code

Things that look wrong but are intentional, dangerous areas, and hard-won lessons.
Claude appends to this file during `/wrap-up` when something worth keeping surfaces.

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

**How Claude uses it:** If you ask "can I refactor the billing flow?", Claude already knows
about the integer-only price rule and the refund retry risk — without you explaining it again.

---

### `CURRENT.md` — re-entry note for next session

Written at `/wrap-up`. Tells Claude exactly where things stand so the next session
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

**How Claude uses it:** Session opens with: *"Picking up from 2026-05-20: async report
export (PROJ-412) — job dispatches, migration pending, next step is the failure handler."*

---

### `decisions/[area].md` — why things are the way they are

One file per domain area. Append-only log of decisions, tradeoffs, and historical context.
Claude prompts you to log entries during `/wrap-up` when a significant "why" surfaces.

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

**How Claude uses it:** When you revisit checkout months later, Claude knows the async
path was already explored and why it was rejected — no re-investigation needed.

---

### `skill-candidates.md` — patterns worth automating

Surfaces during `/wrap-up` when Claude spots something repetitive or manual.

```markdown
# Skill Candidates — myapp

### 2026-05-18 — Ticket → migration → test scaffold
Every bug fix follows the same shape: fetch ticket → read AC → write migration →
write unit test → update CURRENT.md. Took 4+ exchanges to set up each time.
Rough skill: given a ticket number, scaffold migration + test stubs in one shot.
```

---

## To update

Re-run the install command — `SKILL.md` and all templates are overwritten, the
`CLAUDE.md` block is skipped if already present (no duplicates).

## Uninstall

```bash
rm -rf ~/.claude/skills/dev-context/
```

Then remove the `## Dev-Context Skill` block from `~/.claude/CLAUDE.md`.
