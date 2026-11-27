<p align="center">
  <img src="docs/logo.png" alt="NailBiteMenu Icon" width="120" height="120" />
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

- [Open Source](#open-source)
- [Installation](#installation)
- [Usage](#usage)
  - [Threshold](#threshold)
  - [Model Size](#model-size)
- [Alerts](#alerts)
- [Privacy](#privacy)
- [Requirements](#requirements)
- [Feedback](#feedback)

## Open Source

The full **NailBiteMenu macOS app**, including its Swift source and Core ML models, is now **open source**.
You can explore, build, or contribute to it right here:

📂 [`/app`](./app) → contains all app source code and models

💡 Pull requests and issues are welcome!

## Installation

1. **Download** the latest release:  
   👉 [NailBiteMenu.dmg](https://github.com/killian31/NailBiteMenu/releases/latest/download/NailBiteMenu.dmg)

2. **Open** the DMG and **drag** `NailBiteMenu.app` into your **Applications** folder.

3. Open it and allow camera access when macOS asks. The app is signed with a Developer ID and notarized by Apple.

4. NailBiteMenu now runs quietly from your **menu bar**.

> **Tip:** If your menu bar is crowded, macOS may hide the icon behind the chevron (⌃). Drag it out from Control Center to pin it.

## Usage

NailBite runs from your **menu bar**. The main window has three sections:

- **Today**: how long you've been bite-free, today's and this week's episodes, your bite-free streak, and the apps where biting happened.
- **Insights**: episodes per day, a weekday × hour heatmap, average episode length, bite-free days, and top trigger apps over 7 days, 30 days, 90 days, or all time.
- **Settings**: theme (System, Light, Dark), model size, threshold, alerts, and data reset.

Close the window and monitoring keeps running. The menu bar panel shows the bite-free timer, today's count, and your streak, with buttons to pause or open the app.

Detections a few seconds apart are grouped into one **episode**. Streaks and bite-free days only count days the app was monitoring. Everything is stored locally.

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

Each biting episode triggers at most two alerts:

1. **A banner** slides in under the menu bar and names the app you're in. It doesn't steal focus.
2. **A 30-second reset** takes over the screen if you keep biting. It guides you to rest your hands and breathe in and out for four seconds each. This is the competing-response step of habit reversal training. You can turn it off in Settings.

Both have a **Preview** button in Settings.

## Privacy

- All processing happens **on-device**. The camera feed never leaves your Mac.
- The app runs in the App Sandbox **without network access**: no analytics, no cloud services.
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
