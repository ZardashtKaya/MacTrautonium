# MacTrautonium

A polyphonic electronic musical instrument for macOS inspired by Oskar Sala's legendary **Mixtur-Trautonium**, played directly on the MacBook trackpad using raw multi-touch coordinates and Force Touch pressure.

---

## Features

- **Raw Multi-Touch & Force Tracking**: Direct interface with macOS `MultitouchSupport.framework` to capture individual finger IDs, continuous horizontal positions ($X$), vertical manual zones ($Y$), and Force Touch pressure (in grams).
- **True Polyphony**: Multiple fingers can be played simultaneously, each finger driving an independent polyphonic voice with its own subharmonic mixture.
- **Dual Manuals (Sala Configuration)**: Upper half of trackpad = Manual I (Lead/Melody), Lower half = Manual II (Mixtur/Bass), each with distinct waveforms, subharmonic dividers, and formant filters (or full-width single manual mode).
- **Subharmonic Mixture Engine**: PolyBLEP anti-aliased Sawtooth and Neon relaxation tube oscillators ($1 - e^{-kt}$) with 4 subharmonic frequency divider slots ($f_0 / N$, $N \in [1..24]$).
- **Formant Acoustic Resonance Banks**: Parallel 4-stage Topology-Preserving Transform (TPT) State Variable Filters replicating acoustic vowel resonances (**A, E, I, O, U**) across Bass, Tenor, and Soprano registers.
- **MIDI Out & MPE (MIDI Polyphonic Expression)**: Broadcasts high-resolution expressive MIDI to external DAWs (Logic Pro, Ableton Live, Bitwig, Cubase, Reaper) and software synths via a built-in CoreMIDI virtual port (`MacTrautonium MPE`):
  - **MPE Multi-Channel**: Allocates touches across member channels 2–16 with per-finger independent 14-bit pitch bend.
  - **Continuous Pressure (Aftertouch)**: Force Touch pressure transmitted as Channel Aftertouch or Poly Key Pressure.
  - **Slide / Timbre (CC 74)**: Vertical $Y$-axis finger movement transmitted as CC 74 (MPE Slide).
  - **Pitch Bend Range**: Configurable ($\pm 12$, $\pm 24$, $\pm 48$, $\pm 96$ semitones) with automatic RPN broadcast.
  - **Destination Routing**: Output to virtual source or external hardware USB/Bluetooth MIDI endpoints.
- **Global Sound Routing Toggle**: Instant header-bar switcher between `[SYNTH]` (internal audio engine only), `[MIDI OUT]` (mutes internal synth to prevent double-triggering in DAWs while streaming MPE), and `[BOTH]` (layering internal oscillators with external plugins).
- **Dynamic Pressure Expression**: Touch pressure modulates amplitude and dynamically opens filter cutoff brightness (up to 3 octaves), simulating the resistance wire pressed onto the metal rail.
- **42 Musical Scales & Category Browser**: 42 scales across 6 categories (Diatonic & Modes, Jazz & Melodic Minor, Harmonic Modes, Pentatonic & Blues, Symmetric & Modern, and World/Maqams/Ragas) with live note summary banners.
- **Magnetic Snap Intonation**: Fretless continuous glide and natural finger vibrato while moving, with intelligent soft magnetic attraction toward scale notes when a finger rests or slows down.
- **Crackle-Free High-Speed Swipes**: Sub-block (16-sample) State Variable Filter cutoff smoothing, legato glide transient preservation, pre-allocated audio memory, Schmitt-trigger gate hysteresis, and rate-limited asynchronous haptics completely eliminate clicks and pops during fast sweeps across the trackpad.
- **Stereo Peak VU Meters**: Real-time dual-channel audio output meters with smooth decay and green/amber/red saturation clip indicators.
- **Force Touch Haptics**: Subtle tactile clicks whenever fingers cross semitone or scale boundaries.
- **Real-Time 48kHz Audio**: Built natively in Swift using Apple's `AVAudioEngine` and `AVAudioSourceNode` with zero external C or Homebrew dependencies.
- **Performance WAV Recorder**: Direct uncompressed WAV recording to `~/Music/Trautonium Recordings/`.
- **Live Oscilloscope**: 60fps real-time waveform visualizer.

---

## Playing the Instrument

| Gesture / Control | Musical Effect |
|---|---|
| **`[SPACE]` Bar** | **Toggle Play Mode**: Decouples and hides the mouse cursor (`CGAssociateMouseAndMouseCursorPosition(0)`). The trackpad becomes exclusively dedicated to instrument playing so finger gestures never move the cursor or trigger desktop clicks. |
| **`[ESC]`** | Exits Play Mode and restores normal mouse pointer movement to tweak parameters and presets. |
| **Horizontal position ($X$)** | Continuous fretless microtonal pitch (low notes on the left, high notes on the right). |
| **Finger pressure (Force Touch)** | Volume swell and filter brightness (feather touch is quiet and soft; firm pressure is loud and bright). |
| **Upper half ($Y < 0.5$)** | Manual I (Lead register). |
| **Lower half ($Y \ge 0.5$)** | Manual II (Mixtur / Bass register). |
| **Multiple fingers** | Polyphonic chords (each finger triggers its own voice). |
| **Resting finger** | In "Soft Attraction" mode, pitch gently locks into the nearest scale note while preserving vibrato. |
| **Mouse / Pointer** | Click and drag on the ribbon to play without a physical trackpad (when Play Mode is off). |

---

## Building and Running

### Requirements
- macOS 13.0 or later
- Apple Silicon or Intel MacBook with Force Touch trackpad (or Magic Trackpad 2/3)
- Swift 6.0+ (Xcode 15+)

### Quick Run
```bash
# Run directly from terminal:
swift run MacTrautonium
```

### Build Standalone macOS App
```bash
# Package into build/MacTrautonium.app:
./bundle_app.sh

# Launch the app:
open build/MacTrautonium.app
```

### Run Automated Tests
```bash
swift test
```

---

## Preset Management

- **Save Custom Presets**: Click the quick save button (`square.and.arrow.down`) or select **Save Current Preset...** from the Presets menu, enter a custom name, and save your sound design patch.
- **Persistent Storage**: Saved as JSON files in `~/Library/Application Support/MacTrautonium/Presets/`.
- **User Presets Section**: All custom saved presets appear directly in the Presets dropdown alongside the factory presets.
- **Delete / Reveal**: Quick options in the menu to delete custom user presets or reveal the folder in macOS Finder.

---

## Factory Presets

1. **Mixtur Classic (Sala)**: Authentic Oskar Sala setup with Sawtooth on Manual I (subharmonics 2, 3, 4, 5) and Neon tube oscillator on Manual II with vowel "A" formant filter.
2. **The Birds (Hitchcock)**: Avian and screeching synthetic timbres designed by Oskar Sala for Alfred Hitchcock's 1963 film *The Birds*.
3. **Deep Cathedral Organ**: Low 16' and 32' undertones with cathedral reverb.
4. **Vocal Formant Choir**: Vowel formants "E" and "O" for choral vocal textures.
5. **Bowed Cello & Bass**: Rich low-end strings with dynamic pressure brightness.
6. **Subharmonic Chimes & Bells**: Percussive strike envelope with inharmonic subharmonic overtones and tape echo repeats.

---

## Architecture

- **`TrautoniumKit/DSP/`**: PolyBLEP Sawtooth/Neon oscillators, subharmonic frequency division counters, TPT SVF tone filter, 4-stage formant filter bank, Freeverb stereo reverb, and stereo tape delay.
- **`TrautoniumKit/Audio/`**: `AVAudioEngine` and `AVAudioSourceNode` real-time audio pipeline, polyphonic `VoiceManager`, lock-free scope ring buffer, and WAV `AudioRecorder`.
- **`TrautoniumKit/Input/`**: `MultitouchBridge` (`MultitouchSupport.framework`), background runloop touch listener, Force Touch calibration, and haptic triggers.
- **`TrautoniumKit/Model/`**: Continuous pitch mapping, scale masks, magnetic snap tracking, and factory presets.
- **`MacTrautonium/Views/`**: SwiftUI dual-manual ribbon visualizer with glowing orbs, live oscilloscope, Mixtur matrix, and master controls.
