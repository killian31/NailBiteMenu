<p align="center">
  <img src="logo.png" alt="NailBiteMenu Icon" width="120" height="120" />
</p>

<h1 align="center">NailBiteMenu</h1>

<p align="center">
  🧠 A <b>menu bar app</b> that uses your Mac’s camera to detect nail-biting in real time, locally and privately.
  <br/>
  <a href="https://github.com/killian31/NailBiteMenu/releases/latest/download/NailBiteMenu.dmg">
    ⬇️ <b>Download for macOS (DMG)</b>
  </a>
</p>

## 📑 Table of Contents

- [🚀 Installation](#-installation)
- [🧩 Usage](#-usage)
  - [🎛️ Controls](#️-controls)
  - [⚙️ Threshold](#️-threshold)
  - [🧠 Model Size](#-model-size)
- [🔔 Alerts](#-alerts)
- [🔒 Privacy](#-privacy)
- [🧰 Requirements](#-requirements)
- [💬 Feedback](#-feedback)

## 🚀 Installation

1. **Download** the latest release:  
   👉 [NailBiteMenu.dmg](https://github.com/killian31/NailBiteMenu/releases/latest/download/NailBiteMenu.dmg)

2. **Open** the DMG and **drag** `NailBiteMenu.app` into your **Applications** folder.

3. When launching the first time, macOS will warn that it’s from an *unidentified developer*: go to **System Settings → Privacy & Security → Open Anyway**.

4. After that, NailBiteMenu runs quietly from your **menu bar**.

> 💡 **Tip:** If your menu bar is full, some icons may be hidden behind the chevron (⌃).  
> Use the chevron to reveal NailBiteMenu, or relaunch it from Applications.


## 🧩 Usage

### 🎛️ Controls
Click the menu bar icon to open controls.  
You can:
- **Start / Stop monitoring**
- **Adjust detection threshold**
- **Select model size (speed vs. accuracy)**

### ⚙️ Threshold
The threshold controls how sensitive the detection is:
| Threshold | Behavior |
|------------|-----------|
| **Low (e.g. 0.45)** | More sensitive, may trigger false positives |
| **Medium (≈ 0.6)** | Balanced (recommended) |
| **High (e.g. 0.9)** | Less sensitive, only strong detections trigger alerts |

Tweak it depending on lighting conditions and how close you sit to the camera.

### 🧠 Model Size
The app includes several model variants corresponding to different input image size:

| Model | Description | Speed | Accuracy |
|--------|--------------|--------|-----------|
| **224px** | Fastest, lowest power usage | ⚡️⚡️⚡️ | ⭐️⭐️⭐️ |
| **384px** | Better detection accuracy | ⚡️⚡️ | ⭐️⭐️⭐️⭐️ |
| **512** | Highest precision (slower) | ⚡️ | ⭐️⭐️⭐️⭐️⭐️ |

> 💡 Tip: Start with **512px** if running on a Mac with Apple Silicon (M1-M5 chips).
> On an Intel Mac, only the 224px is real-time. Other lodels can still run but will be slower.


## 🔔 Alerts

When nail-biting is detected:
- A popup indicating detection and confidence appears, and is removed either by clicking the button or waiting 3 seconds.
- A notification can appear (if enabled in macOS **Notifications & Focus**).


## 🔒 Privacy

- All processing happens **on-device** using your Mac’s camera feed.
- No frames, images, or metrics leave your computer.
- The app does **not** connect to the internet.


## 🧰 Requirements

- macOS **15.6 Sequoia** or later  
- Camera access permission (requested once on first run)


## 💬 Feedback

Found a bug? Have a suggestion?  
→ [Open an issue](https://github.com/killian/NailBiteMenu/issues)


<p align="center">
  Made with ❤️ on macOS • © 2025 <a href="https://github.com/yourname">yourname</a>
</p>
