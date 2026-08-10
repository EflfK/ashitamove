# AshitaMove

Display-only Ashita v4 addon for ultrawide-safe native menu positioning and
Spectral Focus modal UI coordination.

The addon detects the focused native FFXI menu and publishes its state to other
Spectral Focus addons. Consumers use that state to apply separate temporary
layouts around task-focused panels such as the Auction House and decision
prompts. It never sends input, queues
gameplay commands, injects packets, or automates menu interaction.

## Install

```powershell
.\install.ps1
```

Then load it in game:

```text
/addon load ashitamove
```

To load it automatically with an existing Ashita startup script:

```powershell
.\scripts\enable-startup.ps1 -ScriptPath '<startup script.txt>'
```

## Commands

- `/amove status` — show the focused native menu and modal classification.
- `/amove debug on` — print native menu transitions while developing profiles.
- `/amove debug off` — stop transition logging.

## Spectral Focus integration

The addon broadcasts an `ashitamove_modal_v1` plugin event whenever menu state
changes, refreshes it periodically for consumers loaded mid-menu, and responds
to `ashitamove_modal_query_v1`. The versioned payload has `version`, `active`,
and `menu_name` fields. Display addons can use it to shift, resize, or
temporarily suppress overlays around a native task-focused screen, then restore
the normal layout when that screen closes.
