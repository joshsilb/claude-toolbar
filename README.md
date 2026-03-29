<div align="center">
  <img src="ClaudeIsland/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">ClaudeToolbar</h3>
  <p align="center">
    A macOS menu bar app for managing Claude Code CLI sessions.
    <br />
    <br />
    <a href="https://github.com/joshsilb/claude-toolbar/releases/latest" target="_blank" rel="noopener noreferrer">
      <img src="https://img.shields.io/github/v/release/joshsilb/claude-toolbar?style=rounded&color=white&labelColor=000000&label=release" alt="Release Version" />
    </a>
  </p>
</div>

## Features

- **Menu Bar Status Item** — Compact icon with activity indicators in the system tray
- **Live Session Monitoring** — Track multiple Claude Code sessions in real-time
- **Permission Approvals** — Approve or deny tool executions directly from the dropdown panel
- **Chat History** — View full conversation history with markdown rendering
- **Auto-Setup** — Hooks install automatically on first launch

## Requirements

- macOS 15.6+
- Claude Code CLI

## Install

Download the latest release or build from source:

```bash
xcodebuild -scheme ClaudeToolbar -configuration Release build
```

## How It Works

ClaudeToolbar installs hooks into `~/.claude/hooks/` that communicate session state via a Unix socket. The app listens for events and displays them in a dropdown panel anchored to the menu bar.

When Claude needs permission to run a tool, the panel shows approve/deny buttons — no need to switch to the terminal.

## License

Apache 2.0
