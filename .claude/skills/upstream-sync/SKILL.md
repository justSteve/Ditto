---
name: upstream-sync
description: Check upstream specs and repos for changes that affect the enterprise. Run daily or when investigating spec drift. Covers Agent Skills standard, Claude Code docs, and key dependencies.
allowed-tools: Bash(gh:*), Bash(date:*), Bash(cat:*), Read, Edit, Write, WebFetch, Grep
---

# Upstream Sync

Check upstream specifications and repositories for changes since last sync. Flag anything that affects ECC, skill conventions, or zgent tooling.

## Sources to Monitor

### 1. Agent Skills Specification (agentskills/agentskills)

The open standard behind SKILL.md. No versioned releases — evolves via commits.

```bash
gh api repos/agentskills/agentskills/commits --jq '.[0:10] | .[] | "\(.commit.committer.date | split("T")[0]) \(.commit.message | split("\n")[0])"'
```

Compare against the last-synced date in `references/sync-state.json`.

### 2. Anthropic Skills Examples (anthropics/skills)

Reference skill implementations. New skills or updates to skill-creator are relevant.

```bash
gh api repos/anthropics/skills/commits --jq '.[0:10] | .[] | "\(.commit.committer.date | split("T")[0]) \(.commit.message | split("\n")[0])"'
```

### 3. Claude Code Documentation (code.claude.com)

Skills, hooks, agents, subagents, plugins docs. Check for new features or breaking changes.

Fetch and compare key pages:
- `https://code.claude.com/docs/en/skills`
- `https://code.claude.com/docs/en/hooks`
- `https://code.claude.com/docs/en/sub-agents`
- `https://code.claude.com/docs/en/plugins`

### 4. skills-ref Library Version

```bash
gh api repos/agentskills/agentskills/contents/skills-ref/pyproject.toml --jq '.content' | base64 -d | grep 'version'
```

## Workflow

1. **Read sync state** from `references/sync-state.json` (create if missing)
2. **Check each source** for commits/changes since `last_synced`
3. **Summarize new changes** — list each commit with one-line description
4. **Assess impact** on enterprise artifacts:
   - Does the terminology mapping need updating? (`zgent-ops/terminology-mapping-agent-skills-standard-ecc.md`)
   - Do any deployed SKILL.md files need changes?
   - Are there new frontmatter fields, deprecated features, or behavioral changes?
   - Are there new example skills worth studying?
5. **Apply updates** if impact is found — edit the affected docs
6. **Update sync state** with today's date and a summary of what changed (or "no changes")

## Impact Assessment Checklist

For each new upstream change, ask:

- [ ] Does this add/remove/modify a SKILL.md frontmatter field?
- [ ] Does this change skill resolution, scope, or loading behavior?
- [ ] Does this affect how Claude Code invokes or discovers skills?
- [ ] Does this introduce a new concept ECC should model?
- [ ] Does this deprecate something we depend on?
- [ ] Does this change the eval framework?

If any box is checked, update the terminology mapping and flag for Steve.

## Output

Report format:

```
## Upstream Sync - YYYY-MM-DD

### agentskills/agentskills
- Last synced: YYYY-MM-DD
- New commits: N (or "none")
- [list if any]

### anthropics/skills
- Last synced: YYYY-MM-DD
- New commits: N (or "none")
- [list if any]

### Claude Code Docs
- Changes detected: yes/no
- [details if any]

### Impact: [none | low | medium | high]
- [action items if any]
```
