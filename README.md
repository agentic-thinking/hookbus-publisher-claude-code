# hookbus-publisher-claude-code

Publishes Claude Code lifecycle events to **HookBus**, the vendor-neutral event bus for AI agent runtimes.

Every `UserPromptSubmit`, `PreToolUse`, `PostToolUse` and `Stop` hook Claude Code fires gets forwarded to the bus. Any HookBus subscriber (audit log, cost tracker, policy engine, KB injector, DLP filter) then observes or gates the event.

## What it does

- Registers as four Claude Code hooks (`~/.claude/settings.json`)
- Claude Code spawns `claude-code-gate` per event; the gate posts a HookEvent envelope to HookBus and translates the bus verdict back into Claude Code's per-event output schema
- Fail-open if HookBus is unreachable: Claude Code is never bricked by a missing bus
- Bearer-token authentication against the bus via `HOOKBUS_TOKEN`

## Install

```bash
curl -fsSL https://agenticthinking.uk/install.sh | bash
```

Or manually:

```bash
git clone https://github.com/agentic-thinking/hookbus-publisher-claude-code
cd hookbus-publisher-claude-code
export HOOKBUS_INSTANCE_ID=runtime-instance-01
./install.sh
```

The installer drops `claude-code-gate` to `~/.local/bin/` and prints a ready-to-paste snippet for `~/.claude/settings.json`.

## Configure

Copy the snippet below into `~/.claude/settings.json`, replacing `<TOKEN>` with your HookBus bearer token:

```jsonc
{
  "hooks": {
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "env HOOKBUS_URL=http://localhost:18800/event HOOKBUS_TOKEN=<TOKEN> HOOKBUS_SOURCE=claude-code /home/you/.local/bin/claude-code-gate"
      }]
    }],
    "PreToolUse":  [{ "matcher": "", "hooks": [{ "type": "command", "command": "env HOOKBUS_URL=http://localhost:18800/event HOOKBUS_TOKEN=<TOKEN> HOOKBUS_SOURCE=claude-code /home/you/.local/bin/claude-code-gate" }] }],
    "PostToolUse": [{ "matcher": "", "hooks": [{ "type": "command", "command": "env HOOKBUS_URL=http://localhost:18800/event HOOKBUS_TOKEN=<TOKEN> HOOKBUS_SOURCE=claude-code /home/you/.local/bin/claude-code-gate" }] }],
    "Stop":        [{ "matcher": "", "hooks": [{ "type": "command", "command": "env HOOKBUS_URL=http://localhost:18800/event HOOKBUS_TOKEN=<TOKEN> HOOKBUS_SOURCE=claude-code /home/you/.local/bin/claude-code-gate" }] }]
  }
}
```

Ready-to-paste version in [`settings.example.json`](./settings.example.json).

Get your token from the bus container:

```bash
docker exec hookbus cat /root/.hookbus/.token
```

## Environment variables

| Var | Default | Purpose |
|---|---|---|
| `HOOKBUS_URL` | `http://localhost:18800/event` | Bus HTTP endpoint |
| `HOOKBUS_TOKEN` | _(empty)_ | Bearer token for authenticated bus |
| `HOOKBUS_SOURCE` | `claude-code` | Dashboard source label |
| `HOOKBUS_TIMEOUT` | `30` | HTTP timeout (seconds) |
| `HOOKBUS_PUBLISHER_ID` | `uk.agenticthinking.publisher.anthropic.claude-code` | Stable publisher type identifier |
| `HOOKBUS_USER_ID` | _(empty)_ | Optional user or pseudonymous user reference for shared buses |
| `HOOKBUS_ACCOUNT_ID` | _(empty)_ | Optional runtime/provider account reference |
| `HOOKBUS_INSTANCE_ID` | _(empty)_ | Optional local publisher/runtime instance ID |
| `HOOKBUS_HOST_ID` | _(empty)_ | Optional pseudonymous host, container, or workload ID |

**Do not export `HOOKBUS_SOURCE` in your shell profile.** It leaks into every publisher you run on the same host and mislabels events. Pin it inline per hook command as shown above.

For a central HookBus shared by multiple users or machines, set at least `HOOKBUS_INSTANCE_ID` before installing. Use pseudonymous IDs; do not put raw personal data, passwords, tokens, private IPs, or credentials in identity fields. Pseudonymous IDs are still attributable operational metadata and should follow your retention and access-control policy.

## Failure behaviour

If the bus is unreachable, the gate fails **open**: Claude Code continues normally. For fail-closed (governance-mode), set `HOOKBUS_FAIL_MODE=closed` and the gate will block tool calls when the bus is down.

## Supported Claude Code hook events

| Event | Gate output | Notes |
|---|---|---|
| `UserPromptSubmit` | Plain-text stdout (legacy injection path) | Bus verdict reason injected as context |
| `PreToolUse` | `hookSpecificOutput.permissionDecision` | deny/ask/allow per bus verdict |
| `PostToolUse` | `hookSpecificOutput.additionalContext` (optional) | Observational |
| `Stop` | `{}` on allow, `{"decision":"block","reason":...}` on deny | Stop schema forbids `hookSpecificOutput` |

## AgentHook publisher manifest

This repository ships [`agenthook.publisher.json`](./agenthook.publisher.json), an interim AgentHook publisher manifest for today's non-standard hook surfaces. It declares the stable publisher ID, runtime, supported lifecycle events, limitations, config files, and verification commands in one machine-readable file ahead of native AgentHook adoption.

HookBus and other collectors can use the manifest to show publisher onboarding state and hook coverage, but they should still verify live events before reporting a publisher as active.

## License

MIT. See [`LICENSE`](./LICENSE).

## Contributing

Pull requests welcome. See [`CONTRIBUTING.md`](./CONTRIBUTING.md) and [`CLA.md`](./CLA.md). The project also publishes a [`COVENANT.md`](./COVENANT.md) describing our cultural commitments to the community.

## Related

- [HookBus](https://github.com/agentic-thinking/hookbus) — the bus this publishes to
- [HookBus spec](https://github.com/agentic-thinking/hookbus/blob/main/HOOKBUS_SPEC.md) — envelope protocol
- [hookbus-publisher-hermes](https://github.com/agentic-thinking/hookbus-publisher-hermes) — Hermes runtime publisher
- [hookbus-publisher-openclaw](https://github.com/agentic-thinking/hookbus-publisher-openclaw) — OpenClaw runtime publisher
