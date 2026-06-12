---
name: daysactivity-format
description: DaysActivity.md formatting conventions. Use when writing handoff entries, hourly summaries, or any content destined for DaysActivity.md.
user-invocable: false
---

# DaysActivity.md Format

## Purpose

`DaysActivity.md` is a cumulative daily log that captures session activity in reverse chronological order (newest on top).

## File Location

`/root/projects/Ditto/DaysActivity.md`

## Structure

```markdown
# DaysActivity - YYYY-MM-DD

## HH:MM - [Entry Type]
[Content...]

## HH:MM - [Entry Type]
[Content...]
```

## Entry Types

### Session Handoff
```markdown
## 14:30 - Session Handoff

**Summary**: [What was accomplished]

**State**: GT v0.5.0, Doctor 52/4/2

**Open Work**:
- [Item 1]
- [Item 2]
```

### Hourly Summary

**Rules:**
- **Idle**: Don't add anything (skip if no activity)
- **Active, no file changes**: AI-generated summary evaluating conversation importance
- **Active, with file changes**: List files changed

```markdown
## 14:00 - Hourly Summary

ECC schema design discussion, handoff system planning

Files changed:
zgent-ops/buildECCDb.sql
.claude/commands/handoff.md
```

### Manual Note
```markdown
## 15:45 - Note

[Free-form content]
```

## Formatting Rules

1. **Single-line summaries** stand alone as complete thoughts
2. **File listings** get their own lines (one file per line)
3. **Timestamps** use 24-hour format (HH:MM)
4. **Newest entries** always at top (prepend, don't append)

## Daily Lifecycle

1. **Morning**: `/daily-housekeeping` archives yesterday, creates fresh file
2. **Throughout day**: Entries prepended via `/handoff` or hourly automation
3. **End of day**: Final `/handoff` captures session state
