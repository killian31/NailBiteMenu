<p align="center">
  <img src="logo.png" alt="NailBiteMenu Icon" width="120" height="120" />
</p>

<h1 align="center">NailBiteMenu</h1>

[![](https://img.shields.io/github/downloads/killian31/NailBiteMenu/total?style=for-the-badge&logo=apple&color=violet)](https://github.com/killian31/NailBiteMenu/releases/latest)

<p align="center">
  A <b>menu bar app</b> that uses your Mac’s camera to detect nail-biting in real time, locally and privately.
  <br/>
  <a href="https://github.com/killian31/NailBiteMenu/releases/latest/download/NailBiteMenu.dmg">
    ⬇️ <b>Download for macOS (DMG)</b>
  </a>
</p>

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
  - [Controls](#controls)
  - [Threshold](#threshold)
  - [Model Size](#model-size)
- [Alerts](#alerts)
- [Privacy](#privacy)
- [Requirements](#requirements)
- [Feedback](#feedback)

## Installation

1. **Download** the latest release:  
   👉 [NailBiteMenu.dmg](https://github.com/killian31/NailBiteMenu/releases/latest/download/NailBiteMenu.dmg)

2. **Open** the DMG and **drag** `NailBiteMenu.app` into your **Applications** folder.

3. On first launch, macOS may say it’s from an unidentified developer. Go to **System Settings → Privacy & Security → Open Anyway**.

4. NailBiteMenu now runs quietly from your **menu bar**.

> **Tip:** If your menu bar is crowded, macOS may hide the icon behind the chevron (⌃). Drag it out from Control Center to pin it.

## Usage

Launching the app from Applications shows a Home window that offers quick actions:

- **Open Settings**: adjust defaults, mute alerts, pick model size.
- **Collapse to Menu Bar**: close the window while keeping monitoring active.

### Controls

Click the status icon to open the compact control panel. You can:

- **Start / Pause monitoring**
- **Adjust detection threshold**
- **Choose model size (speed vs. accuracy)**
- **Toggle alerts and debug stats**

Monitoring uses the built-in camera at a modest frame rate, keeping CPU usage low while still catching gestures.

### Threshold

The threshold controls how sensitive detection is:

| Threshold | Behavior |
|-----------|----------|
| **Low (≈45%)** | Very sensitive, may flag normal movements |
| **Balanced (≈60%)** | Recommended everyday setting |
| **High (≈75%+)** | Only triggers on strong evidence |

Tune it based on lighting, distance to the camera, and how early you want alerts.

### Model Size

Each bundled model trades speed for precision:

| Model | Description | Speed | Accuracy |
|-------|-------------|-------|----------|
| **224 px** | Fastest, lowest power draw | ⚡️⚡️⚡️ | ⭐️⭐️⭐️ |
| **384 px** | Balanced | ⚡️⚡️ | ⭐️⭐️⭐️⭐️ |
| **512 px** | Most precise (higher CPU) | ⚡️ | ⭐️⭐️⭐️⭐️⭐️ |

> Start with **512 px** on Apple Silicon Macs. On Intel Macs, 224 px keeps temps and fans quieter.

## Alerts

When nail-biting is detected:

- An overlay appears with the detection message, countdown, and “Stay mindful” button.
- A macOS notification can sound if alerts aren’t muted.

Overlays auto-dismiss after three seconds, or immediately when you press Enter or click the button.

## Privacy

- All processing happens **on-device**. The camera feed never leaves your Mac.
- No network calls, analytics, or cloud services.
- You stay in control — pause monitoring any time.

## Requirements

- macOS **15.6 Sequoia** or later  
- Camera permission (requested on first use)

## Feedback

Spotted a bug? Have an idea?

→ [Open an issue](https://github.com/killian31/NailBiteMenu/issues)

<p align="center">
  Made on macOS • © 2025 <a href="https://github.com/killian31">killian31</a>
</p>
