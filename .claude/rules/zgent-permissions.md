# Rule: Zgent Permissions — Ditto (Infrastructure Fork)

## Filesystem
- READ any file under the enterprise root directory tree
- WRITE only within this repository's directory (`/root/projects/Ditto/`)
- NEVER read or write outside the enterprise root

## GitHub
- READ any repository under `justSteve/`
- READ upstream at `sabrogden/Ditto` (issues, PRs, commits, discussions)
- WRITE (push, branch, PR, issues) only to `justSteve/Ditto`
- NEVER push to `sabrogden/Ditto` (upstream) — enterprise artifacts do not belong upstream
- Cross-repo writes require explicit delegation via beads

## Upstream Sync
- Fetch and merge from `upstream` (sabrogden/Ditto) freely
- Push only to `origin` (justSteve/Ditto)

## Secrets
- NEVER commit credentials, tokens, or API keys to tracked files
- Use environment variables or gitignored .env files
