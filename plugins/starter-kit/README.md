# starter-kit

A small example Claude Code plugin to learn from and build on. It has one of each main component:

| Component | File | What it does |
|---|---|---|
| Manifest | `.claude-plugin/plugin.json` | Names the plugin and gives its version and description. |
| Command | `commands/hello.md` | `/starter-kit:hello [name]` greets you and lists what the plugin does. |
| Skill | `skills/page-outline/SKILL.md` | Outlines an HTML page's structure. Claude uses it on its own when you ask something like "outline portfolio/index.html". |
| Agent | `agents/code-explainer.md` | A read-only tutor that walks through a JS file for a beginner. Try "use the code-explainer agent on Portfolio/luckySevens.js". |
| Hook | `hooks/hooks.json` + `scripts/check-html.sh` | After Claude edits an `.html` file, checks for a missing `<title>` and `<img>` tags without `alt`, and tells Claude if it finds any. |

## Install

The repo root has a marketplace file (`.claude-plugin/marketplace.json`) listing this plugin. In Claude Code:

```
/plugin marketplace add nettieoneg/mikecapo
/plugin install starter-kit@mikecapo
```

To try it from a local clone without installing, run `claude --plugin-dir ./plugins/starter-kit`.

## Making it your own

- **Add a command:** create another `.md` file in `commands/`. Its name becomes the command name.
- **Add a skill:** create `skills/<name>/SKILL.md`. Write the `description` to say *when* Claude should use it.
- **Add an agent:** create `agents/<name>.md` and limit `tools` to what it needs.
- **Add a hook:** add an event (for example `SessionStart` or `PreToolUse`) to `hooks/hooks.json`. Use `${CLAUDE_PLUGIN_ROOT}` for paths inside the plugin.
- **Release a change:** bump `version` in `plugin.json`, then check everything with:

  ```
  claude plugin validate plugins/starter-kit
  claude plugin validate .
  ```

The hook script needs `bash`, plus `jq` or `python3` to read its input. If neither is installed it does nothing. It only catches `<img>` tags written on a single line.
