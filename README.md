# Plane Claude Marketplace

Official Claude Code plugin marketplace for Plane — bringing Plane workspace context, work item management, and role-based agents directly into your editor.

## Available Plugins

| Plugin | Description |
|:-------|:------------|
| [plane-workspace](./plugins/plane-workspace/) | Connect Claude Code to your Plane workspace. Two-step setup wizard, personal role-based agent, helper agents, and full work item workflows. |

## Adding to Claude Code

```
/plugin marketplace add mguptahub/plane-claude-marketplace
```

Then browse and install plugins from the marketplace list.

---

## For Plane Team

To add a new plugin: create a directory under `plugins/` with a `.claude-plugin/plugin.json` and register it in `.claude-plugin/marketplace.json`.
