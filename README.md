# Jackdaw

A local-first personal AI that spawns sub-agents to work on your ideas, watches your
PC and LAN, and stays out of the way while you game.

Status: **Phase 0**. The packaging skeleton is real; the sensors and orchestrator are not.

## Install

macOS and Linux:

    curl -fsSL https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.sh | sh

Windows PowerShell:

    irm https://raw.githubusercontent.com/jackbashroot-boop/Jackdaw/main/install.ps1 | iex

Both verify a published SHA-256 before installing, and both support `--uninstall`.

## Use

    jackdaw version
    jackdaw changelog
    jackdaw changelog added
    jackdaw doctor

## Design decisions worth knowing

- **.NET 8, self-contained.** One binary per platform, no runtime install.
- **The model runs in a separate process** (llama.cpp with the Vulkan backend for AMD).
  This app is only an HTTP client, so swapping models never touches the code.
- **Windows service plus unprivileged clients.** The tray, CLI, and LAN dashboard all
  talk to one elevated core over a named pipe.
- **`changelog.json` is the single source of truth.** `CHANGELOG.md` and the in-app
  changelog are both rendered from it.

## Roadmap

| Phase | Scope |
|---|---|
| 0 | Packaging, changelog pipeline, release pipeline |
| 1 | Core service, IPC, SQLite store, tray, dashboard shell |
| 2 | Local model wiring and the gaming guard (measure FPS before adding features) |
| 3 | Host telemetry, rule engine, alerts |
| 4 | Network telemetry, router integration, LAN discovery |
| 5 | Response actions with approval gates |
| 6 | Remote agents for Pi, NAS, and Linux hosts |
| 7 | The self-extension loop |

## Not to be confused with

There are other projects called Jackdaw. If you arrived here by accident, you may have
wanted the [Bevy level editor](https://github.com/jbuehler23/jackdaw) or the
[Active Directory recon tool](https://github.com/skelsec/jackdaw).

## Licence

MIT.
