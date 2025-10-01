# 🗡️ HEMA Scoring Machine

A lightweight, open-source **timer and scoring app** for Historical European Martial Arts (HEMA) bouts.  
Designed for clarity, speed, and offline use during tournaments and sparring sessions.

---

## ⚙️ Features

- 🕐 **Customizable Timer**
  - Set time easily (tap to edit, +/− controls)
  - Millisecond precision
  - Auto-stop vibration when time runs out

- ⚔️ **Score Tracking**
  - Tap to increment/decrement scores
  - Prevents negative values
  - Swap fighter sides instantly

- 🚨 **Warnings & Doubles**
  - Quick +/− warning counters per fighter
  - Central double-hit counter

- 🧾 **Fight Log**
  - Automatically records score & warning changes per start/stop cycle
  - Viewable via drag-up “Logs” panel

- 🎨 **Clean Interface**
  - Large readable fonts (`RobotoMono`)
  - Compact layout optimised for phones
  - Colour contrast for visibility

- 📳 **Haptic Feedback**
  - Vibrates when the timer ends

- 🪄 **Open Source & Offline**
  - No ads, no tracking, no internet required

---

## 📦 Installation

### 🧭 From F-Droid (recommended)
*(Pending approval — will update when published)*

You’ll soon find **HEMA Scoring Machine** on [F-Droid](https://f-droid.org/).

### 🛠️ Manual Install
1. Download the latest `.apk` from [Releases](https://github.com/kstepanovdev/hema_scoring_machine/releases)
2. Enable “Install unknown apps” on your Android device
3. Open the file to install

---

## 🧰 Build from Source

You can build and sign it yourself:

```bash
git clone https://github.com/yourname/hema_scoring_machine.git
cd hema_scoring_machine
flutter pub get
flutter build apk --release
