Activate the email-slack briefing hook for this session.

Read `$CLAUDE_PLUGIN_ROOT/user/plane-workspace.json` to find the EA helper (if configured) in `$CLAUDE_PLUGIN_ROOT/user/agents/`.

If an EA helper agent exists, activate it with:
- Set up a recurring cron every 15 minutes: check unread emails (last 1h) + recent Slack messages, send a plain text DM summary to the user on Slack. Format all times in the user's local timezone.
- Run an immediate full briefing (last 24h) right after setting up the cron.
- Send a macOS notification after the briefing is sent.

If no EA helper is configured, suggest running `/helpers add ea` first.
