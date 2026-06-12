# Convention: tmux When It Helps

Claude Code's Bash is the default execution environment. Use tmux via
`tmux send-keys` when it genuinely adds value — not as a hard gate.

## Default: Bash

Run commands in Claude Code's Bash for diagnostics, file operations, git,
short-lived commands, and anything where Claude needs the output.

## When tmux is right

- Steve explicitly asks
- Interactive programs expecting a real terminal
- Long-running services or daemons
- Live-watch scenarios
- Multi-pane orchestration
