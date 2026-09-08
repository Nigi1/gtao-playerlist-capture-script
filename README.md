# Playerlist Capture

An AutoHotkey v2 script that automates capturing and posting the GTA Online lobby playerlist to Discord.

## What it does

- Automatically detects the current lobby player count
- Determines whether one or two playerlist pages need to be captured
- Takes the necessary screenshot(s)
- Pastes the screenshot(s) directly into the Discord chat box
- Pastes a custom command used to trigger the update
- You just double-check everything looks right and hit **Enter** to send
- Optionally captures the playerlist automatically on a timer (AutoMode), instead of pressing the hotkey each time
- Lets you tweak the paste command temporarily, or change any setting permanently, without editing `config.ini` by hand
- Validates settings from `config.ini` and the Settings GUI, automatically falling back to safe defaults if something's invalid

## Requirements

- Discord **desktop app** (the browser version of Discord is not currently supported — may be added in the future)
- GTA Online, running at one of the supported resolutions

## Supported Resolutions

| Resolution             | Status                                    |
| ---------------------- | ----------------------------------------- |
| HD (1280x720)          | ✅ Supported                              |
| Full HD (1920x1080)    | ✅ Supported                              |
| 1440p (2560x1440)      | ✅ Supported                              |
| 2160p (3840x2160)      | ✅ Supported                              |
| Ultrawide              | ✅ Supported                              |
| Resolutions in between | ⚠️ Untested (may work, may need tweaking) |

## Installation

1. Go to the [Releases](https://github.com/Nigi1/gtao-playerlist-capture-script/releases) page.
2. Download the latest `.zip` file (contains the `.exe` and `config.ini`).
3. Extract the `.zip` to a folder of your choice.
4. Open `config.ini` and set your preferences (see [Configuration](#configuration) below).
5. Run the `.exe` to start the script.

## Configuration

All settings are stored in `config.ini` and can be edited two ways:

### Via the Settings GUI (recommended)

Press your configured `SettingsHotkey` to open a settings window where you can edit hotkeys, the paste command, the overlay toggle key, the safezone setting, and AutoMode. Changes are saved directly to `config.ini` and applied immediately — no restart needed. Invalid input (e.g. duplicate hotkeys, an out-of-range interval) is rejected with an explanation, so you can't save a broken configuration.

### Editing config.ini directly

```ini
[Hotkeys]
CaptureHotkey=F10
TempCommandHotkey=F6
SettingsHotkey=F7

[Settings]
Command=!sesh update 1
OverlayToggleKey=z
SafezoneSetting=7
AutoMode=false
ScreenshotInterval=10
```

| Setting              | Description                                                                                        |
| -------------------- | -------------------------------------------------------------------------------------------------- |
| `CaptureHotkey`      | The key you press to trigger the full capture-and-paste sequence, or to start/stop AutoMode        |
| `TempCommandHotkey`  | Opens a window to change the command for the current session only (not saved to config.ini)        |
| `SettingsHotkey`     | Opens the settings window, where all values can be edited and saved permanently to config.ini      |
| `OverlayToggleKey`   | The in-game key used to open/close the player list overlay                                         |
| `Command`            | The text/command pasted into Discord alongside the screenshot(s)                                   |
| `SafezoneSetting`    | Set to a value between 0 and 10 to match the ingame slider                                         |
| `AutoMode`           | When enabled, pressing `CaptureHotkey` starts a repeating capture loop instead of a single capture |
| `ScreenshotInterval` | How often (in minutes) a screenshot is taken automatically while AutoMode is running               |

If you edit `config.ini` manually and enter an invalid value (e.g. a hotkey that doesn't exist, an interval outside 0–60), the script will fall back to a safe default, correct the file automatically, and show a warning on startup listing what was fixed.

If editing manually, reload the script for changes to take effect. Changes made via the Settings GUI apply immediately.

## Usage

1. Launch GTA Online and Discord (desktop app).
2. (Optional) Press your `TempCommandHotkey` to change the pasted command for this session only.
3. Press your configured `CaptureHotkey`.
4. The script will:
    - Open playerlist
    - Detect the player count
    - Capture one or two screenshots as needed
    - Paste everything into Discord along with the command
5. Review the pasted content, then press **Enter** to send.

### AutoMode

If `AutoMode` is enabled in the settings, pressing `CaptureHotkey` will ask whether you want to start an automatic capture loop instead of a single capture:

1. Press `CaptureHotkey`.
2. Confirm you want to start automatic captures.
3. The script will repeat the capture-and-paste sequence every `ScreenshotInterval` minutes, without requiring you to press Enter each time.
4. Press `CaptureHotkey` again and confirm to stop the loop at any time.

> ⚠️ **Note:** Since captures happen unattended, there's no way for the script to detect problems that would normally interrupt a manual capture — for example, if a player joins the lobby while a screenshot is being taken, the playerlist may get forced closed mid-capture. The script doesn't account for this and may end up capturing whatever was on screen instead (e.g. the game world instead of the playerlist). Occasional failed captures are possible while AutoMode is running, so it's worth spot-checking the posted screenshots periodically.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
