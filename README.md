<p align="right"><a href="README.zh_CN.md">Chinese</a> · <strong>English</strong></p>

# AI Passport — Doubao Voice Microphone

Turn the [FoloToy AI Passport](https://github.com/FoloToy/ai-passport) wearable card into a
**wireless voice-input microphone**: press OK, speak, and the text lands at the cursor on your Mac.

This is a derivative of [Passport Mic](https://github.com/MatchlessHeroHx/ai-passport-mic) (MIT).
Upstream targets Chatterfly dictation with a right-Control hotkey; this version targets the
**Doubao input method with a right-Option hotkey**, and drops the separate helper
binary for key injection. See [differences from upstream](docs/differences-vs-upstream.md).

## How it works

```text
AI Passport  ──BLE (16 kHz IMA ADPCM, bonded)──▶  menu-bar app  ──▶  BlackHole 2ch  ──▶  dictation IME
  OK / UP / DOWN                                     decode + key injection
```

| Device key | Sent to macOS | Effect |
| --- | --- | --- |
| OK (press) | one right Option | IME starts listening; the device starts recording |
| OK (press again) | one right Option | IME finishes and inserts text; recording stops |
| UP | ⌘Z | undo the previous insertion |
| DOWN | Return | send / newline |

Audio always goes to `BlackHole 2ch`, so any app that can pick a microphone works. Set the
IME's voice shortcut to **right Option** to get push-to-talk dictation.

## Hardware

ESP32-C3, 8 MB flash, no PSRAM, ES8311 codec, ST7789P3 240×320, three ADC-ladder keys,
BLE 5 LE, 500 mAh battery.

> The ESP32-C3 has no Classic Bluetooth, no USB OTG, and ESP-IDF 5.5.3 has no LE Audio,
> so it cannot appear as a native Bluetooth or USB microphone. A host-side companion is
> mandatory — that is why this project exists.

## Install

```bash
source ~/esp/esp-idf/export.sh        # ESP-IDF 5.5.3
./tools/validate.sh --firmware        # build/FoloToy-AI-Passport-full.bin
python -m esptool --chip esp32c3 -p /dev/cu.usbmodemXXXX -b 460800 \
  write_flash 0x0 build/FoloToy-AI-Passport-full.bin
```

Then install [BlackHole 2ch](https://existential.audio/blackhole/), run
`bash companion/build-mac.sh`, grant **Bluetooth** and **Accessibility** to Terminal,
and start with `companion/Start.command`.

Set the IME's voice shortcut to **right Option** and its microphone to `BlackHole 2ch`.

## Known limitations

- **No zero-config auto-start.** macOS (verified on 27) does not grant Bluetooth or
  Accessibility to background `launchd` processes. Adding `Start.command` to login items is
  the current workaround; it still involves Terminal.
- Voice-grade audio only (16 kHz, 4-bit ADPCM).
- Battery runtime on continuous BLE streaming is not measured.
- UP/DOWN act on whatever window has focus; an accidental DOWN inserts a newline.
- Firmware disables all logging and owns the USB serial port, so `idf.py monitor` is silent.

## License

MIT, inherited from [FoloToy AI Passport](https://github.com/FoloToy/ai-passport) and
[Passport Mic](https://github.com/MatchlessHeroHx/ai-passport-mic).
Original copyright notices are preserved in [LICENSE](LICENSE) and [NOTICE](NOTICE).
