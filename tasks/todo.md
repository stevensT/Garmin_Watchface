# RescueFace — Fenix 8 Pro Watch Face — Project Spec

> Working checklist. "RescueFace" is a working name — rename freely.
> Revised 2026-08-27 after Phase 0 research against the installed SDK.

## Context

Trevor wants a new watch face for his **Garmin Fenix 8 Pro, 51 mm AMOLED**, to wear
daily. A throwaway Monkey C scaffold ("Stanferd Face", targets fenix7x) exists in the
old OneDrive project folder and is reference only — this repo is the real work.

Goal: a **minimal, clean digital** face — large HH:MM, a second-time readout defaulting
to UTC/ZULU, and 6 user-assignable data slots — configurable from both the Garmin
Connect phone app and the Fenix 8 on-device editor, with a proper dimmed always-on
variant.

## Verified environment facts (measured, not assumed)

| Fact | Value |
|---|---|
| SDK | **9.2.0** (2026-06-09) at `%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2` |
| Trevor's device id | **`fenix8pro47mm`** — profile covers *"fēnix 8 Pro 47mm / 51mm / MicroLED / quatix 8 Pro 47mm / 51mm"*. One target hits the 51 mm watch. |
| Resolution | **454×454** round, `deviceFamily: round-454x454` |
| Display | **AMOLED**, 16 bpp, `alphaBlendingSupport: true`, `enhancedGraphicSupport: true` |
| API level | **6.0** (`deviceGroup: "API level 6.0"`) — *not* "System 8"; that was marketing naming |
| Watch face memory | **128 KB** (`appTypes.watchFace.memoryLimit = 131072`) — the real budget |
| Max PRG filespace | 64 MB |
| Launcher icon | 65×65 · complication icon 45×45 |
| AOD API | `requiresBurnInProtection`, `isSleepMode` both present |
| VS Code ext | `garmin.monkey-c-1.1.3` installed |
| Java | **OpenJDK 21** at `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot` (machine PATH) |
| Measured memory | **6.5 kB / 123.9 kB** used by the Phase 1 face — ample headroom |
| Launcher icon | 65×65 for the 454 devices, but **`fenix843mm` wants 60×60** — needs a per-device resource in Phase 6 |

### Corrections to the original spec

1. **Garmin has no no-code declarative watch face format.** That is Google Wear OS.
   Garmin faces are **Monkey C + layout XML**.
2. **"System 8" is not an API level.** These devices report **API level 6.0**;
   `minApiLevel` is set to **5.1.0** (what `WatchFaceConfig` requires).
3. **The on-device editor is a fixed schema, not arbitrary properties.** The SDK sample
   `samples/ConfigurableWatchFace` declares `resources/configs/watchface.xml` and
   supports exactly four config types:
   `WATCH_FACE_CONFIG_TYPE_STYLE`, `_ACCENT_COLOR`, `_COMPLICATION`, `_COMPLICATION_COLOR`.
   Background colour and all toggles cannot live there — they stay in phone settings.
4. **Data slots are Garmin Complications**, and **there is no second-timezone
   complication.** So the ZULU slot is a custom slot type we render ourselves.

### Available complication types (44 in SDK 9.2.0)

Covers nearly everything wanted, with **no extra permissions** beyond
`ComplicationSubscriber` — Garmin supplies the value, label, and update pushes:

`DATE`, `WEEKDAY_MONTHDAY`, `BATTERY`, `STEPS`, `HEART_RATE`, `BODY_BATTERY`,
`CALORIES`, `FLOORS_CLIMBED`, `INTENSITY_MINUTES`, `STRESS`, `PULSE_OX`,
`RESPIRATION_RATE`, `RECOVERY_TIME`, `SLEEP_SCORE`, `TRAINING_STATUS`,
`CURRENT_TEMPERATURE`, `CURRENT_WEATHER`, `HIGH_LOW_TEMPERATURE`,
`FORECAST_WEATHER_1DAY/2DAY/3DAY`, `SUNRISE`, `SUNSET`, `ALTITUDE`,
`SEA_LEVEL_PRESSURE`, `NOTIFICATION_COUNT`, `CALENDAR_EVENTS`, `SOLAR_INPUT`,
`VO2MAX_RUN`, `VO2MAX_BIKE`, `WEEKLY_RUN_DISTANCE`, `WEEKLY_BIKE_DISTANCE`,
`WHEELCHAIR_PUSHES`, `LAST_GOLF_ROUND_SCORE`, `RACE_PREDICTOR_*`, `RACE_PACE_PREDICTOR_*`.

**Not available as complications** → must be custom-drawn: the big time, seconds, and
**second time zone / UTC-ZULU**.

### Confirmed decisions

| Topic | Decision |
|---|---|
| Platform | Monkey C watch face, `minApiLevel 5.1.0` |
| Targets | **`fenix8pro47mm`** (Trevor's, 454×454), **`fenix847mm`** (454×454), **`fenix843mm`** (416×416) — AMOLED only |
| Data slots | **6 slots**, each user-assignable |
| Slot mechanism | **Hybrid** — a slot holds either a **Complication** or the custom **SecondTime** type |
| Second time | A **data slot type**, default **UTC/ZULU**, user-configurable offset + label |
| Styles | **2** — Minimal and Full |
| Colours | Accent (time) + Data colour via on-device editor; background via phone settings |
| Always-on | User on/off; purpose-built dimmed low-power render |
| Seconds | User on/off; likely unavailable in always-on (pixel budget) |
| Animations | None — static |
| Branding | Small, minimal **"RESCUE"** mark (toggle + editable text) |
| Fonts / art | Built-in system fonts to start; placeholder launcher icon |
| Language | English only |
| Distribution | Build store-ready; publishing/paid deferred |
| Battery priority | Moderate (3/5) |
| Interaction | Passive in normal mode; tap handling only in editor mode (required by the config API) |

## Architecture

```
RescueFace/
  manifest.xml          watchface, minApiLevel 5.1.0, 3 products, ComplicationSubscriber
  monkey.jungle
  developer_key         4096-bit PKCS8 DER — gitignored, never commit
  source/
    RescueFaceApp.mc       AppBase; detects :launchedFromWatchFaceSettingsEditor
    RescueFaceView.mc      WatchFace; onLayout/onUpdate/onEnterSleep/onExitSleep;
                           implements updateConfiguration() + getComplication()
    RescueFaceDelegate.mc  editor-mode input delegate (tap -> slot selection)
    Config.mc              phone-settings properties; typed accessors; cache
    Theme.mc               accent/data/background -> palette + dimmed palette
    Layout.mc              Minimal/Full slot rects, proportional to dc (454 & 416)
    SlotRenderer.mc        draws one slot: complication value, or SecondTime
    SecondTime.mc          custom UTC/ZULU provider (offset + label)
    LowPowerRenderer.mc    dimmed subset, burn-in offset, pixel-budget aware
  resources/
    configs/   watchface.xml   <- ON-DEVICE EDITOR SCHEMA (styles, colors, slots)
    settings/  properties.xml  settings.xml   <- PHONE APP SETTINGS
    strings/   strings.xml
    drawables/ launcher_icon.png (65x65), drawables.xml
    layouts/   layout.xml
```

**Two configuration surfaces, deliberately split:**

| Surface | Owns |
|---|---|
| **On-device editor** (`resources/configs/watchface.xml`) | Style (Minimal/Full), Accent colour, the 6 data slots, Data colour. Up to 4 saved variants on the watch. |
| **Phone settings** (`properties.xml` + `settings.xml`) | Background colour, 12/24h, Show seconds, Always-on enable, Always-on seconds, Second-time offset + label, RESCUE mark on/off + text, temperature unit. |

**Render flow.** `onUpdate` draws background → big HH:MM (accent colour) → optional
seconds → the 6 slots via `SlotRenderer` (data colour) → RESCUE mark. Complication
slots read cached values pushed by `Complications.registerComplicationChangeCallback`;
the SecondTime slot computes from `Time.now()` + configured offset.
`onEnterSleep`/`onExitSleep` flip `_lowPower`; when low-power **and** always-on is
enabled, `LowPowerRenderer` takes over: dimmed palette, fewer elements, per-minute
position shift for burn-in, lit pixels held under ~10 %.

**Editor mode.** `onStart` reads `state[:launchedFromWatchFaceSettingsEditor]`. In
editor mode the view gets a delegate, complication subscriptions are skipped, and
`getComplication()` returns a `ComplicationDrawableRef` so the system can highlight the
slot being edited.

## Implementation order

### Phase 0 — Environment & scaffolding
- [x] Connect IQ **SDK 9.2.0** installed
- [x] Device profiles present (`fenix8pro47mm`, `fenix847mm`, `fenix843mm`)
- [x] VS Code **Monkey C** extension `garmin.monkey-c-1.1.3` installed
- [x] Generate **new developer key** (4096-bit PKCS8 DER) — `developer_key`, gitignored
- [x] Confirm device id, resolution, API level, memory budget (table above)
- [x] `git init` done; `.gitignore` written before the key was generated
- [x] Create skeleton: `manifest.xml`, `monkey.jungle`, resource/source dirs
- [x] **Java installed** — Microsoft OpenJDK 21 at `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot`, on the *machine* PATH
- [ ] Add SDK `bin/` to PATH (currently prepended per-command; see Commands in CLAUDE.md)
- [x] Face **builds and launches in the simulator** on `fenix8pro47mm` — verified visually
- [x] All three targets build clean
- [ ] First git commit

### Phase 1 — Static minimal face
- [x] Background fill + large centred **HH:MM**, system font, 12/24h (12h drops the leading zero)
- [x] `Theme.mc` with a hardcoded palette + `dim()` helper for Phase 5
- [x] Small **RESCUE** mark
- [x] UTC/ZULU readout — **verified correct against real UTC** (`0349Z` vs system 03:50)
- [x] Simulator screenshot at 454×454 looks right
- [ ] Decide final type scale / positions once slots exist (Phase 3 may move the ZULU line)

### Phase 2 — On-device editor config (do this early — it shapes everything)
- [ ] `resources/configs/watchface.xml`: 2 `<styles>`, `<accentColors allowAny="true"/>`, 6 `<complication>` entries, `<dataColors>` list
- [ ] `RescueFaceApp` editor-mode detection; `RescueFaceDelegate`
- [ ] `updateConfiguration()` handling all four `WATCH_FACE_CONFIG_TYPE_*` values, with defaults for every null
- [ ] `WatchFaceConfig.getSettings(null)` null-guard (device without support)
- [ ] Verify the editor flow in the simulator

### Phase 3 — Slots & complications
- [ ] `SlotRenderer` + slot geometry; 6 slots wired to unique identifiers
- [ ] `Complications.subscribeToUpdates` per slot + change callback; cache values
- [ ] Graceful `--` when a complication has no value or is unsupported
- [ ] `SecondTime.mc` — custom slot type, default UTC/ZULU, offset + label from phone settings
- [ ] Watch memory: confirm 6 live subscriptions fit the 128 KB budget

### Phase 4 — Phone settings & styles
- [ ] `properties.xml` / `settings.xml` / `strings.xml` for the phone-owned knobs
- [ ] `Config.mc` with cache + reload on `onSettingsChanged`
- [ ] `Layout.mc` Minimal + Full slot rects, proportional; tune for 416×416
- [ ] Test both styles at both resolutions

### Phase 5 — Always-on / low-power
- [ ] `_lowPower` via `onEnterSleep`/`onExitSleep`; honour `requiresBurnInProtection`
- [ ] `LowPowerRenderer`: dimmed palette, reduced elements, per-minute pixel shift, ≤10 % lit
- [ ] Seconds hidden in low-power unless enabled and hardware allows
- [ ] Always-on toggle gates the behaviour

### Phase 6 — Polish & store-readiness
- [ ] Launcher icon art (65×65)
- [ ] `settings.xml` UX pass; English strings review
- [ ] Sim matrix: style × resolution × normal/always-on; screenshots
- [ ] Register watch as a developer device; side-load; wear test; verify on-watch editor
- [ ] (Deferred) Connect IQ Store listing

## Verification

- **Build:** `monkeyc -f monkey.jungle -y developer_key -d fenix8pro47mm -o bin/RescueFace.prg -w` (repeat for `fenix847mm`, `fenix843mm`).
- **Simulator:** `connectiq` then `monkeydo bin/RescueFace.prg fenix8pro47mm`. Exercise the settings editor, simulate time/date, battery, HR/steps, and sleep/wake for always-on.
- **Editor:** launch the watch face settings editor in the sim; change style, accent, data colour, and each slot; confirm `updateConfiguration` applies each without a restart.
- **Slots:** each shows a sane value with live sim data and `--` when absent; SecondTime tracks UTC and honours a non-zero offset.
- **Always-on:** dimmed render, seconds behaviour correct, position shifts each minute, lit-pixel share within budget.
- **Memory:** check the sim's memory viewer stays under 128 KB with all 6 slots subscribed.
- **On-device:** side-load to the Fenix 8 Pro; create up to 4 editor variants; confirm they apply.

## Risks / open items

- ~~Java not installed~~ — resolved, OpenJDK 21.
- **128 KB watch face budget** with 6 live complication subscriptions — measure early in Phase 3. Baseline is 6.5 kB, so the headroom is real but subscriptions are the unknown.
- **AOD ~10 % pixel budget**: live seconds in always-on may not be feasible; the toggle may ship disabled.
- Whether the on-device editor caps the number of complication slots below 6 — verify in Phase 2 before building layout around 6.
- `fenix843mm` at 416×416 may need its own font sizing rather than pure proportional scaling.
- MicroLED variants share the `fenix8pro47mm` profile but may behave differently for always-on — untestable without hardware.
