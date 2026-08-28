# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**RescueFace** — a Garmin Connect IQ **watchface** in Monkey C for the Fenix 8 AMOLED
family. Minimal digital design: large HH:MM, a second-time readout defaulting to
UTC/ZULU, and 6 user-assignable data slots.

`tasks/todo.md` is the living spec and phase checklist — **read it first**; it carries
the verified device facts, the two-surface configuration design, and current progress.

## Environment

The Connect IQ SDK is **not** on PATH by default. It lives at:

```
$SDK="$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"
```

`monkeyc.bat` shells out to `java`, so a **JDK/JRE must be installed and on PATH** —
the SDK does not bundle one.

## Commands

Run from the repo root.

```sh
# Build for the simulator (Trevor's watch; also covers 51mm and MicroLED)
monkeyc -f monkey.jungle -y developer_key -d fenix8pro47mm -o bin/RescueFace.prg -w

# Other targets
monkeyc -f monkey.jungle -y developer_key -d fenix847mm  -o bin/RescueFace.prg -w
monkeyc -f monkey.jungle -y developer_key -d fenix843mm  -o bin/RescueFace.prg -w

# Launch simulator, then side-load
connectiq
monkeydo bin/RescueFace.prg fenix8pro47mm

# Store package
monkeyc -e -f monkey.jungle -y developer_key -o bin/RescueFace.iq -w
```

From VS Code: **Ctrl+F5** builds and opens the simulator.

> **`monkeyc` does not reload a running simulator.** The simulator keeps executing the
> binary that `monkeydo` loaded, so after any source change you must rebuild *and*
> re-run `monkeydo` — otherwise you are looking at stale output and will "fix" bugs
> that are already fixed. When a change appears not to have taken effect, compare the
> `monkeydo`/`java` process start time against the `.prg` mtime before touching the code.

`manifest.xml` is a generated file — change app id, products, permissions, and
languages through the "Monkey C: Edit …" command-palette actions rather than by hand.

### Tests

No test suite. Monkey C supports `(:test)` functions via `monkeyc --unit-test` +
`monkeydo … -t` if that becomes worthwhile.

## Device facts that constrain design

| | |
|---|---|
| Target id | `fenix8pro47mm` — covers Fenix 8 Pro **47mm, 51mm, and MicroLED** |
| Resolution | 454×454 round (`fenix843mm` is 416×416) |
| Display | AMOLED, 16 bpp, alpha blending + enhanced graphics |
| API level | 6.0; manifest `minApiLevel` 5.1.0 (what `WatchFaceConfig` needs) |
| **Memory** | **128 KB** for a watch face — the binding constraint |
| Always-on | Once-per-minute updates, ~10 % max lit pixels, burn-in shifting required |

## Architecture

**Two configuration surfaces, and it matters which owns what:**

1. **On-device editor** — `resources/configs/watchface.xml`. A *fixed* schema, not
   arbitrary properties. Supports exactly four things: `<styles>` (layout preset),
   `<accentColors>` (the time colour), `<data>` complication slots, and `<dataColors>`.
   Read at runtime via `Application.WatchFaceConfig.getSettings(null)`; changes arrive
   in `updateConfiguration(config, editedType)` keyed by
   `WATCH_FACE_CONFIG_TYPE_{STYLE,ACCENT_COLOR,COMPLICATION,COMPLICATION_COLOR}`.
   Users can save up to 4 variants on the watch.

2. **Phone settings** — `resources/settings/{properties,settings}.xml`, read through
   `Config.mc`. Owns everything the editor schema cannot express: background colour,
   12/24h, seconds toggle, always-on toggles, second-time offset + label, RESCUE mark.

**Data slots are Garmin Complications**, subscribed via
`Complications.subscribeToUpdates` + `registerComplicationChangeCallback`. Garmin
supplies value and label, so weather/sunrise/altitude need **no extra permissions**
beyond `ComplicationSubscriber`. There is **no second-timezone complication** — the
UTC/ZULU slot is a custom type rendered by `SecondTime.mc`, which is why
`SlotRenderer` dispatches on slot type rather than assuming a complication.

**Editor mode** is a distinct runtime mode: `onStart` reads
`state[:launchedFromWatchFaceSettingsEditor]`. When true the view takes an input
delegate, skips complication subscriptions, and implements `getComplication()` to hand
the system a `ComplicationDrawableRef` for the slot being edited.

`samples/ConfigurableWatchFace` in the SDK is the reference implementation for all of
the above — consult it before guessing at the config API.

## Conventions

- The **`developer_key`** is a private signing key, gitignored, and must never be
  committed or pasted into output.
- Keep an eye on the 128 KB budget: prefer computing over caching, and measure in the
  simulator's memory viewer when adding slots or subscriptions.
