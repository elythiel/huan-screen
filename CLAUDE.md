# CLAUDE.md

Huan Screen is a macOS menu bar app (Swift 6, AppKit, IOKit, no dependencies) that drives the WLMOUSE HUAN 8K receiver and its mouse through HID feature reports. The README documents the features and the USB protocol.

## Build and run

- `make app` builds `build/Huan Screen.app` with `swiftc` (universal binary, ad-hoc signed). SwiftPM is not used: there is no `Package.swift`, do not add one or run `swift build`.
- `make install` builds, quits the running app, installs it into `/Applications` and relaunches it. Run it after every change so the result can be tested.
- `make check-localizations` checks that every `localized("…")` key has a translation in `Resources/fr.lproj/Localizable.strings` and that none is unused. CI runs it.
- `make icon` regenerates `Resources/AppIcon.icns` from `scripts/make-icon.swift`.
- `make bump V=x.y.z` sets the version in `Resources/Info.plist`, commits it and creates the annotated tag. Pushing the tag triggers the release workflow.
- A build must have no error and no warning, except the known linker warning about `libswiftCompatibilityPacks.a` missing `x86_64`.

## Architecture

- `HuanScreenApp` starts the menu bar app, or the command line interface when an argument is given.
- `HIDChannel` owns the HID device. Callers go through `perform`, which runs a whole block of transactions on its serial queue (never on the main thread or the cooperative pool) and resumes them with the result.
- `Receiver` matches the receiver and the mouse when it is plugged in with its cable (`A864` HUAN, `A859` HUAN M), follows plug and unplug events and exposes the receiver and mouse commands. Mouse commands go to the wired mouse when it is plugged in, since the receiver loses it then, and through the receiver otherwise.
- `MouseInfo` and `Firmware` read and decode the mouse state and the firmware versions.
- `StatusBarController` builds the menu. `MouseSettingsMenus` and `SettingMenu` hold the DPI, polling rate and lift-off distance submenus. `UpdatesMenu`, `FirmwareRows` and `MenuRowView` draw the Updates submenu, whose rows keep the menu open.
- `UpdateChecker`, `UpdateInstaller` and `UpdateController` check GitHub releases and install updates. `FirmwareController` compares the firmware with the WLMOUSE Hub's `env-models.json`.
- `LowBatteryNotifier` sends the low battery notifications and is the notification center delegate.

## Conventions

- Code, UI strings, README and release notes are in English. Every UI string goes through `localized("…")` with a literal English key and gets its French translation.
- No comments in the code.
- Swift 6 strict concurrency: UI types are `@MainActor`, HID I/O stays on `HIDChannel`'s queue, nothing blocks the main thread or the cooperative pool.
- The command line output (`get`, `info`, `cat`, `status`, `toggle`) and exit codes are relied on by scripts: keep them stable.
- Commit messages: gitmoji, conventional type, then a French description, for example `✨ feat: un sous-menu permet de changer la fréquence de polling`.

## Hardware safety

- A real receiver and mouse are usually plugged in. Read commands (`80` and up) are safe to run.
- Never send a write command (screen mode, DPI, polling rate, lift-off distance or anything else) to the device without asking first. To test a new write command, send the value the device already has and check it is unchanged.
- Never touch firmware update or image upload commands.
