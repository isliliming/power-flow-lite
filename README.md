# Power Flow Lite

> See where your MacBook's power comes from and where it goes.

Power Flow Lite is a small, native macOS menu-bar utility that shows where your
MacBook's power is coming from and where it is going. Its live Sankey-style view
covers the four Power Flow situations described by AlDente:

- adapter powers the Mac while the battery is idle;
- adapter power splits between the Mac and a charging battery;
- battery powers an unplugged Mac;
- adapter and battery jointly power the Mac when the adapter cannot meet demand.

This is an independent implementation and is not affiliated with AlDente or
AppHouseKitchen. It visualizes power only: it does not change charging behavior,
write SMC keys, or set a charge limit.

## A vibe-coded open-source project

Power Flow Lite was created through vibe coding by Liming Li in collaboration
with OpenAI Codex. The product direction, testing, and release decisions are
human-led, while AI assisted with design, implementation, documentation, and
iteration. The complete source is published here so the community can inspect,
audit, improve, and learn from it.

## Why it is lightweight

- native SwiftUI menu-bar app, with no Electron runtime;
- reads IOKit in-process every five seconds while closed and once per second
  while the popover is open;
- no root helper, shell polling, analytics, network access, or account;
- the asynchronously rendered diagram animates at 12 FPS only while its
  popover is visible;
- app bundle is ad-hoc signed for local use.

## Requirements

- macOS 13 Ventura or later;
- a MacBook with a built-in battery;
- Apple Silicon is recommended for complete plugged-in telemetry.

Power Flow Lite uses the `PowerTelemetryData` dictionary exposed by the
`AppleSmartBattery` I/O Registry service. `SystemPowerIn` is available on current
Apple Silicon MacBooks, but it is not a documented public Apple API and can vary
by model or macOS release. On systems without it, the app labels fallback values
as estimated, or shows an em dash rather than inventing a wattage.

## Build and run

No Xcode project or external package is required; Apple's Command Line Tools are
enough.

```bash
./scripts/build_app.sh
open "dist/Power Flow Lite.app"
```

The finished app is written to `dist/Power Flow Lite.app`. You can drag it into
Applications if you want to keep it. Click its menu-bar item to open the live
diagram; use **Quit** at the bottom of the popover to stop it.

Run the calculation and live-hardware checks with:

```bash
./scripts/check.sh
```

## Calculation

The raw battery voltage is in millivolts and current is in milliamps:

```text
battery W = abs(voltage_mV × current_mA) / 1,000,000
```

With an adapter attached, `SystemPowerIn / 1000` is measured adapter input. The
remaining paths follow conservation of energy:

```text
charging:     Mac W = adapter W - battery-charge W
underpowered: Mac W = adapter W + battery-discharge W
unplugged:    Mac W = battery-discharge W
```

These are live estimates rather than billing-grade measurements. A 50 mA
deadband suppresses zero-current sensor noise.

## Privacy and safety

All readings remain on the Mac. The app performs read-only IOKit calls and has no
network code. It never changes the charge controller, so quitting it has no
effect on normal macOS charging.
