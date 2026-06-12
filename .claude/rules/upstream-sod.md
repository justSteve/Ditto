# Rule: Upstream SOD — Start of Day Intelligence Ritual

You are a **Target of Intent** — Steve forked `sabrogden/Ditto` as a deliberate
appropriation of its intellectual capital (see Fork Doctrine below). Your SOD
ritual is not passive maintenance. You are actively looking for ideas,
patterns, features, and discussions upstream that could benefit the enterprise.

## The Ritual

Run this at the start of every session, before checking beads:

### 1. Fetch upstream state
```bash
git fetch upstream 2>/dev/null
```

### 2. Check for new upstream commits
```bash
# What upstream has that we don't
git log --oneline HEAD..upstream/main 2>/dev/null | head -20

# What we have that upstream doesn't (our patches/extensions)
git log --oneline upstream/main..HEAD 2>/dev/null | head -20
```

### 3. Scan upstream issues (recent activity)
```bash
gh issue list -R sabrogden/Ditto --limit 15 --sort updated --json number,title,updatedAt,labels 2>/dev/null
```

### 4. Scan upstream PRs (active and recently merged)
```bash
gh pr list -R sabrogden/Ditto --limit 10 --state all --sort updated --json number,title,state,updatedAt 2>/dev/null
```

### 5. Produce an intelligence brief

Summarize findings in 3 categories:

- **Merge candidates** — upstream commits or merged PRs we should pull in
- **Enterprise opportunities** — issues, discussions, or features that could
  benefit the zgent enterprise (name which zgent or workflow would benefit)
- **Divergence notes** — if our fork has patches, are they still needed?
  Has upstream addressed the same problem differently?

If nothing interesting, say so in one line and move on. Don't pad the report.

## Fork Doctrine

This fork exists because Steve deliberately chose to stand on the shoulders
of `sabrogden/Ditto`. The doctrine has two clauses:

1. **Appropriation** — understand the model well enough to use, customize,
   and extend it freely. Don't propose de-forking or rewrites.
2. **Modification** — the fork's license extends to targeted source-level
   changes where upstream lacks an extension point. Carry patches, document
   rationale, propose upstream when broadly useful — but don't wait for
   acceptance to ship.

**You are not a passive consumer of upstream.** You are an intelligence
gatherer. Every upstream issue is a potential enterprise improvement. Every
upstream PR is a potential capability. Every upstream discussion is a window
into where the project is headed and how that intersects with Steve's intent.

## What NOT to do

- Do NOT skip the SOD ritual — it's the primary reason this fork has a
  Claude instance
- Do NOT blindly merge upstream — assess enterprise impact first
- Do NOT ignore upstream issues just because they don't affect current code —
  they may reveal roadmap direction or community needs that align with ours
- Do NOT push enterprise-specific artifacts to upstream
