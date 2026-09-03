---
name: browser-automation
description: Drive a real browser for ad-hoc, interactive web tasks — opening pages, clicking, filling forms, screenshots, scraping, or quickly eyeballing a site or UI. For scripted Playwright test runs against a local app under development, use webapp-testing instead.
---

# Browser automation with agent-browser

Use the `agent-browser` CLI (already on PATH) for browser tasks. Prefer it
over the Playwright MCP tools: it drives a persistent daemon, so state
(open page, logins) survives across commands and even across sessions.

Before your first commands, read the version-matched usage guide it ships:

```bash
agent-browser skills get core        # overview + common patterns
agent-browser skills get core --full # full command reference
```

Quick shape of a session:

```bash
agent-browser open https://example.com
agent-browser snapshot -i            # accessibility tree with @refs, interactive only
agent-browser click @e3
agent-browser fill @e5 "text"
agent-browser screenshot page.png
agent-browser close --all            # when done — the daemon persists otherwise
```

Target elements by `@ref` from the latest snapshot rather than CSS
selectors. Specialized guides exist for Electron apps, Slack, and
exploratory testing: `agent-browser skills list`.

Scripted end-to-end tests with assertions are the exception — use the
webapp-testing skill (Playwright) for those, not this CLI.
