# Rink Music

An iPhone app for running music at hockey games. Four sections:

| Section | What it does |
|---|---|
| **Warmup** | Tap **Start Warmup** and the warmup playlist plays in order for 3:00 (adjustable), then fades out automatically. A big countdown shows the time left. |
| **Stinger** | Short clips for stoppages. Tap a clip to play it, or use **Play Random**. |
| **Goal** | Goal songs/horns for home-team goals. |
| **Penalty** | Penalty clips. |

Nothing plays on its own. Music starts only when you tap something. The bar at the bottom always shows what's playing, with **FADE** (1.5 s fade-out) and **STOP** (instant stop) buttons.

## Importing audio
Tap **+** in any section and pick one or more files from the Files app (iCloud Drive, On My iPhone, Dropbox, Google Drive…). MP3, M4A/AAC, WAV and AIFF all work. The app copies each file into its own storage, so the original can be deleted afterward. Songs bought or downloaded from Apple Music are copy-protected and can't be imported.

## Editing a clip
Tap the slider icon on a clip to open the timeline editor:
- **Trim**: drag the white start/end handles on the waveform, use −/+ to nudge by 0.1 s, or tap **Set to Playhead**.
- **Playhead**: tap or drag the waveform. While previewing, the playhead follows the music, so you can stop right on the beat and set the end there.
- **Split** cuts the clip into two clips at the playhead.
- **Fade in / fade out** run from 0 to 15 s.
- **Volume** sets each clip's level (0–100%).
- You can also rename the clip or move it to a different section.

Volume and fade changes apply live while a preview is playing. Swipe left on a clip to delete or duplicate it. Duplicating lets you cut several segments from one song. Tap **Edit** to reorder clips (this sets the warmup play order).

## Building
Requires a Mac with Xcode 15 or newer. The app targets iOS 17+.

**Option A, XcodeGen (quickest):**
```sh
brew install xcodegen
cd RinkMusic
xcodegen
open RinkMusic.xcodeproj
```

**Option B, manually:**
1. In Xcode, choose File → New → Project → iOS App. Name it `RinkMusic`, set Interface to SwiftUI and Language to Swift.
2. Delete the generated `ContentView.swift` and `RinkMusicApp.swift`, then drag every `.swift` file from `RinkMusic/` into the project.
3. Under Target → Signing & Capabilities, click **+ Capability** → **Background Modes** and check **Audio, AirPlay, and Picture in Picture**. This keeps music playing when the screen locks.
4. Set the deployment target to iOS 17.0.

Then select your team under Signing & Capabilities, plug in the iPhone, and press Run. A free Apple ID works for installing on your own phone. Sideloaded apps signed that way expire after 7 days. A paid developer account ($99/yr) gives 1-year signing and TestFlight.

## Game-day tips
- Connect to the arena PA over Bluetooth, AirPlay, or a Lightning/USB-C-to-3.5 mm cable. Set the iPhone's volume to max and control loudness on the board.
- Turn on Do Not Disturb or Airplane Mode (keep Bluetooth on if you use it) so calls and notifications don't interrupt playback.
- Music keeps playing when the ringer switch is on silent.
