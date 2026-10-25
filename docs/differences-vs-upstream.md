<p align="right"><a href="differences-vs-upstream.zh_CN.md">简体中文</a> · <strong>English</strong></p>

# Differences from upstream Passport Mic

- Upstream: [MatchlessHeroHx/ai-passport-mic](https://github.com/MatchlessHeroHx/ai-passport-mic) (MIT)
- Baseline commit: `143a22a chore: publish only what Passport Mic needs`
- Goal: turn the "Chatterfly dictation remote" into a general voice-input microphone that targets
  the **Doubao input method (豆包输入法)** by default.

## Summary

**The firmware is untouched.** BLE service, FPM1 framing, ADPCM parameters, UI and BSP are all
upstream. Only the macOS side (`companion/`) was reorganised: the voice hotkey moved from right
Control to right Option, key injection moved in-process, and missing Accessibility now degrades
instead of aborting.

## File-by-file

| File | Change | Reason |
| --- | --- | --- |
| `companion/passport_mic.py` | Keys posted in-process via Quartz; `KEY` constant removed; startup check uses `AXIsProcessTrusted()` and only warns; new `PM_VOICE_KEY` / `PM_KEY_COMMAND` env vars; strings generalised to "dictation app" | Accessibility is not inherited by child processes (evidence below) |
| `companion/chatterfly_key.swift` | Deleted | Its behaviour is now inline in Python |
| `companion/build-mac.sh` | Drops `swiftc` and `codesign`, keeps venv only | No Swift helper to compile |
| `companion/requirements.txt` | Adds `pyobjc-framework-Quartz==10.3.2` | In-process key posting |
| `companion/Start.command` | Removes the `chatterfly-key --request-access` pre-check | The old check aborted startup when unauthorised |
| `companion/bridge_status.py` | Corrected Accessibility hint | It now points at Terminal |
| `README*`, `docs/differences-vs-upstream.*`, `NOTICE` | Rewritten / added | This fork's documentation |

Unchanged: `main/`, `components/bsp/`, `sdkconfig.defaults`, `partitions.csv`, `tests/`, `tools/`.

## Behaviour differences

| Item | Upstream | This fork |
| --- | --- | --- |
| Voice hotkey | right Control (Chatterfly) | **right Option (Doubao)**, switch with `PM_VOICE_KEY=ctrl` |
| Injection | spawns `chatterfly-key` | in-process `CGEventPost` |
| Missing Accessibility | exits with an error | warns, audio keeps working, keys skipped |
| Startup pre-check | requires authorised helper | none |
| Dependencies | bleak / numpy / pyserial / sounddevice | plus `pyobjc-framework-Quartz` |

OK / UP (⌘Z) / DOWN (Return) semantics are unchanged.

## Why injection had to move in-process

Accessibility in macOS is granted per *responsible process*. Measured on macOS 27 (Apple Silicon):

| Launch chain | Result |
| --- | --- |
| Terminal → Python → `chatterfly-key` | works (inherits Terminal's grant) |
| launchd → Python → `chatterfly-key` | fails (`AXIsProcessTrusted()=false`) |
| App bundle → Python → `chatterfly-key` | fails (chain breaks after several layers) |
| Python posts `CGEventPost` itself | works (the grant is its own) |

Grants do not cross process boundaries, so upstream's "spawn a helper" design only works when
started from a terminal. Posting keys inside the bridge makes the grant and the sender the same
process.

## Approaches tried and rejected

| Approach | Result |
| --- | --- |
| LaunchAgent running Python directly | `BLE is not authorized`; Accessibility false |
| `PassportMic.app` + LaunchAgent | `AXIsProcessTrusted()=false` in background |
| Bundle launched with `open -a` | self-signed bundle not executed, still unauthorised |
| App holds grant + FIFO to post keys | architecture sound, but the app cannot get the grant in background |
| Re-signing and re-granting repeatedly | ad-hoc `cdhash` changes on every rebuild, invalidating TCC |

Conclusion: background processes cannot obtain Bluetooth or Accessibility on current macOS,
so this fork does not promise zero-config auto-start. `Start.command` (or a login item) is used.

## Measured protocol behaviour

- OK press sends `START`; the host must reply `A` within 2 s or the device returns to idle
- Heartbeat `P` every 500 ms; the device stops streaming after 3 s without it
- Audio: 20 ms frames, 320 samples, 164-byte ADPCM; congestion drops frames and fills silence
- If a flash write is interrupted, `erase-region 0x0 0x10000` parks the chip in ROM download mode
- The board keeps running on battery when USB is unplugged; a cold start needs a ~2 s power-key hold

## Keeping upstream behaviour

```bash
PM_VOICE_KEY=ctrl companion/Start.command
```

returns the hotkey to right Control for Chatterfly.
