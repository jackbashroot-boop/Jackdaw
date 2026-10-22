# Agents

Every sub-agent is a TOML file in `agents/`. Nothing is hidden in code.

| Field | Meaning |
|---|---|
| `role` | Unique name. Also the filename. |
| `goal` | One sentence. This is most of the system prompt. |
| `model` | `tiny` for routing and classification, `local` for reasoning, `cloud` for escalation. |
| `tools` | Allowlist. A sub-agent can only call what is listed. |
| `trigger` | When it runs: `schedule`, `event`, or `manual`. |
| `limits` | Cost and action ceilings so one agent cannot run away. |
| `policy` | `dry_run` and which actions need your approval. |

## Rules

1. **Nothing writes without approval by default.** `dry_run = true` until you flip it.
2. **Tool output arrives as structured JSON**, never raw text, so log content cannot inject instructions into the prompt.
3. **Every action is reversible and logged**, with the evidence that triggered it.
4. **Agents can create agents**, but the new file is written and shown to you before it runs.

Phase 7 adds the self-extension loop. Until then, write these by hand.
