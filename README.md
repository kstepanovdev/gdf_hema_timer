# HEMA Scoring Machine

A lightweight, open-source **timer and scoring app** for Historical European Martial Arts (HEMA) bouts.
Designed for clarity, speed, and offline use during tournaments and sparring sessions.

---

## Features

- **Customizable Timer**
  - Set time easily (tap to edit, +/− controls)
  - Millisecond precision
  - Auto-stop vibration when time runs out

- **Score Tracking**
  - Tap to increment/decrement scores
  - Prevents negative values
  - Swap fighter sides instantly

- **Warnings & Doubles**
  - Quick +/− warning counters per fighter
  - Central double-hit counter

- **Fight Log**
  - Automatically records score & warning changes per start/stop cycle
  - Viewable via drag-up “Logs” panel

- **Clean Interface**
  - Large readable fonts (`RobotoMono`)
  - Compact layout optimised for phones
  - Colour contrast for visibility

- **Haptic Feedback**
  - Vibrates when the timer ends

- **Open Source & Offline**
  - No ads, no tracking, no internet required

---

## Installation

### From F-Droid (recommended)
[F-Droid GDF HEMA Timer](https://f-droid.org/en/packages/com.gdf.hema_timer)

### From App Store
[App Store GDF HEMA Timer](https://apps.apple.com/us/app/gdf-hema-timer/id6754407702)

### Manual Install
1. Download the latest `.apk` from [Releases](https://github.com/kstepanovdev/gdf_hema_timer/releases)
2. Enable “Install unknown apps” on your Android device
3. Open the file to install

---

## Build from Source

You can build and sign it yourself:

```bash
git clone https://github.com/yourname/gdf_hema_timer.git
cd gdf_hema_timer
flutter pub get
flutter build apk --release
```

## Contributing
Contributions are welcome!
  1. Fork the repo
  2. Create a new branch: git checkout -b feature/my-improvement
  3. Commit your changes: git commit -am 'Add feature'
  4. Push and open a Pull Request
