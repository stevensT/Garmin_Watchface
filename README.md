# RescueFace

A minimal digital watch face for the Garmin Fenix 8 AMOLED family, written in
Monkey C for Connect IQ.

The design is a large `HH:MM` readout, a second-time line defaulting to UTC/ZULU,
a small `RESCUE` mark, and six user-assignable data slots. Not all of it is built yet.

## Status

The static face works. Time, the ZULU readout, and the branding mark render on all
three device profiles, at both 454×454 and 416×416. Configuration, data slots, and
the always-on render come next.

## Supported devices

| Target | Covers | Resolution |
|---|---|---|
| `fenix8pro47mm` | Fenix 8 Pro 47mm / 51mm / MicroLED | 454×454 |
| `fenix847mm` | Fenix 8 47mm | 454×454 |
| `fenix843mm` | Fenix 8 43mm | 416×416 |

All are AMOLED at API level 6.0, with a 128 KB memory budget for a watch face.

## Requirements

- Connect IQ SDK 9.2.0. It is not on `PATH` by default. It lives under
  `%APPDATA%\Garmin\ConnectIQ\Sdks\`.
- A JDK or JRE on `PATH`. `monkeyc.bat` shells out to `java`, and the SDK does not
  bundle one.
- A developer key at `./developer_key`. This is a private signing key. It is
  gitignored and must never be committed.
- The Monkey C extension for VS Code, if you want Ctrl+F5 to build and open the
  simulator.

## Build

Run from the repo root.

```sh
# Build for the simulator
monkeyc -f monkey.jungle -y developer_key -d fenix8pro47mm -o bin/RescueFace.prg -w

# Other targets
monkeyc -f monkey.jungle -y developer_key -d fenix847mm -o bin/RescueFace.prg -w
monkeyc -f monkey.jungle -y developer_key -d fenix843mm -o bin/RescueFace.prg -w

# Store package
monkeyc -e -f monkey.jungle -y developer_key -o bin/RescueFace.iq -w
```

## Run in the simulator

```sh
connectiq                                    # launch the simulator
monkeydo bin/RescueFace.prg fenix8pro47mm    # side-load the build
```

`monkeyc` does not reload a running simulator. After any source change, rebuild and
re-run `monkeydo`, or you are looking at a stale binary.

## Layout

```
manifest.xml        generated; edit it through the "Monkey C: Edit ..." command palette actions
monkey.jungle       build config
source/
  RescueFaceApp.mc    AppBase entry point
  RescueFaceView.mc   the watch face render
  Theme.mc            colour palette and dimming helper for always-on
resources/
  strings/            app name, RESCUE mark text
  drawables/          launcher icon
```

## Configuration (planned)

Configuration lives on two surfaces, split by what each one can express.

The on-device editor (`resources/configs/watchface.xml`) owns the layout style, the
accent colour, the six data slots, and the data colour. Its schema is fixed, and the
watch stores up to four saved variants.

Phone settings (`resources/settings/`) own everything that schema cannot hold:
background colour, 12/24h, seconds, the always-on toggles, the second-time offset
and label, and the RESCUE mark.

Data slots are Garmin Complications, so weather, sunrise, and altitude need no
permissions beyond `ComplicationSubscriber`. Garmin has no second-timezone
complication, so RescueFace draws the UTC/ZULU slot itself.
