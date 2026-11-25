# Huan Screen

macOS menu bar app to switch the **WLMOUSE HUAN 8K receiver** screen between cat and status modes — no driver, no web hub.

- **Cat mode**: the receiver shows its animated cat (or your custom image).
- **Status mode**: the receiver shows the mouse stats (DPI, polling rate, battery…).

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

| Action | Result |
| --- | --- |
| Click | Switch between cat and status modes |
| Right-click (or Control-click) | Menu: pick a mode, toggle **Open at Login**, quit |

The icon reflects the current mode and is dimmed when the receiver is not plugged in. The state is refreshed every 15 seconds and whenever the receiver is plugged or unplugged.

> When the cat is asleep (screen saver), the receiver only redraws on the next mouse activity. Clicking the menu bar icon is mouse activity, so the screen wakes up right after switching.

### Command line

The app binary doubles as a CLI, handy for Raycast, Shortcuts or a keyboard shortcut:

```sh
HUAN=~/Applications/"Huan Screen.app"/Contents/MacOS/HuanScreen

$HUAN get      # prints "cat" or "status"
$HUAN cat
$HUAN status
$HUAN toggle
```

It exits with a non-zero status if the receiver is not found.

## Protocol

Found by reading the official WLMOUSE web hub. The receiver exposes a vendor HID interface (usage page `0xFFFF`) with 64-byte feature reports and no report ID.

Each command is a feature report write followed by a feature report read about 30 ms later. The response echoes the request header and carries the value at byte 6.

| Byte | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Request | `00` | `00` | `00` | `01` | `05` | command | value |
| Response | `A1` | `00` | `00` | `01` | `05` | command | value |

| Command | Meaning | Value |
| --- | --- | --- |
| `0A` | Set status display | `00` cat, `01` status |
| `8A` | Get status display | — |

## Disclaimer

Not affiliated with or endorsed by WLMOUSE. Use at your own risk.

## License

[MIT](LICENSE)
