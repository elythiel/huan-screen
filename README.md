# Huan Screen

macOS menu bar app to switch the **WLMOUSE HUAN 8K receiver** screen between cat and status modes — no driver, no web hub.

- **Cat mode**: the receiver shows its animated cat (or your custom image).
- **Status mode**: the receiver shows the mouse stats (DPI, polling rate, battery…).

The menu also shows the mouse battery level, DPI, polling rate and lift-off distance.

## Requirements

- macOS 13 (Ventura) or later
- A WLMOUSE HUAN 8K receiver plugged in (USB `36A7:A863`)

No special permission is needed: the app talks to the receiver's vendor HID interface, which macOS does not protect behind Input Monitoring.

## Download

1. Download `HuanScreen-<version>.zip` from the [latest release](https://github.com/elythiel/huan-screen/releases/latest).
2. Unzip it and move `Huan Screen.app` to `/Applications`.
3. Open it.

The app is not notarized by Apple, so macOS blocks it on first launch. To allow it, either:

- open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to the Huan Screen message;
- or remove the quarantine flag from a terminal:

  ```sh
  xattr -dr com.apple.quarantine "/Applications/Huan Screen.app"
  ```

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone git@github.com:elythiel/huan-screen.git
cd huan-screen
make install
open ~/Applications/"Huan Screen.app"
```

`make app` only builds `build/Huan Screen.app` (universal binary, ad-hoc signed). `make release` also zips it into `build/HuanScreen-<version>.zip`, the version coming from `Resources/Info.plist`. `make uninstall` removes the app from `~/Applications`.

## Usage

### Menu bar

Click the icon to open the menu:

```
▭ 76%
1600 DPI · 1000 Hz · LOD 1 mm
───────────────
✓ Cat mode
  Status mode
───────────────
  Open at Login
  Quit Huan Screen
```

The battery turns red below 20% and shows a bolt while charging. The icon reflects the current mode and is dimmed when the receiver is not plugged in.

Everything is refreshed every 15 seconds, when the receiver is plugged or unplugged, and when the menu opens. A sleeping mouse does not answer: the menu then keeps the last known values.

> When the cat is asleep (screen saver), the receiver only redraws on the next mouse activity. Picking a mode in the menu is mouse activity, so the screen wakes up right after switching.

### Command line

The app binary doubles as a CLI, handy for Raycast, Shortcuts or a keyboard shortcut:

```sh
HUAN=~/Applications/"Huan Screen.app"/Contents/MacOS/HuanScreen

$HUAN get      # prints "cat" or "status"
$HUAN info     # prints the battery level, DPI, polling rate and lift-off distance
$HUAN cat
$HUAN status
$HUAN toggle
```

It exits with a non-zero status if the receiver is not found.

## Protocol

Found by reading the official WLMOUSE web hub. The receiver exposes a vendor HID interface (usage page `0xFFFF`) with 64-byte feature reports and no report ID.

Each command is a feature report write followed by a feature report read (30 ms later for the receiver, 60 ms for the mouse, which answers over the air). Commands from `80` upwards are reads.

| Byte | 0 | 1 | 2 | 3 | 4 | 5 | 6… |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Request | `00` | `00` | target | length | group | command | parameters |
| Response | status | `00` | target | length | group | command | values |

- **Target**: `00` receiver, `02` mouse (relayed by the receiver).
- **Status**: `A1` success, `A2` error (for instance when the mouse is asleep).

### Receiver

| Request (bytes 2–6) | Meaning | Response values |
| --- | --- | --- |
| `00 01 05 0A <v>` | Set status display | — (`v`: `00` cat, `01` status) |
| `00 01 05 8A` | Get status display | `00` cat, `01` status |

### Mouse

| Request (bytes 2–7) | Meaning | Response values |
| --- | --- | --- |
| `02 02 00 83` | Battery | charging (`01`), level in % |
| `02 01 00 85` | Active profile | profile (1-based) |
| `02 02 01 82 <profile>` | Active DPI stage | profile, stage (1-based) |
| `02 0A 01 81 <profile> 06` | DPI stages | profile, count, then X and Y per stage (16-bit big-endian) |
| `02 02 01 80 <profile>` | Polling rate | profile, code: `08` 125, `04` 250, `02` 500, `01` 1000, `20` 2000, `40` 4000, `80` 8000 Hz |
| `02 03 01 88 <profile>` | Lift-off distance | profile, `01`/`02` mm, `0x80 + tenths`, or BCD (`0x12` = 1.2 mm) |

## Disclaimer

Not affiliated with or endorsed by WLMOUSE. Use at your own risk.

## License

[MIT](LICENSE)
