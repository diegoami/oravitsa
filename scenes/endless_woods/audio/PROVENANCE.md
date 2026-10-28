# Endless woods audio provenance

Every file here is **original, procedurally synthesized audio**, generated on
2026-10-28 by `tools/synth_audio.py` from fixed random seeds using only the
Python standard library (filtered noise, sine partials and envelopes). No
recordings, samples, sound libraries, paid services or generative-AI audio
models were used. The files are dedicated to the public domain under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) along with the
generator.

Rebuild with `python3 tools/synth_audio.py`; `--check` reports whether the
committed files still match the generator on this platform (floating-point
libraries may differ slightly between platforms).

| File | Use | Synthesis |
|---|---|---|
| `ambience_wind.wav` | 23 s loop, forest bus | Double low-passed noise with slow integer-cycle swells and a band-passed leaf rustle; 2 s equal-power seam crossfade |
| `ambience_birds.wav` | 19 s loop, forest bus | Seeded warble, paired-note and trill phrases over silence |
| `wolf_howl.wav` | Wolf call | Rising/falling harmonic tone with vibrato and breath noise |
| `lynx_growl.wav` | Lynx call, warnings | Amplitude-modulated band-passed noise over a low tone |
| `boar_grunt.wav` | Boar call | Three filtered pulse-train grunts |
| `deer_bark.wav` | Deer call | Two formant-filtered noise bursts with a falling tone |
| `fox_yip.wav` | Fox call | Three short rising harmonic yips |
| `hare_thump.wav` | Hare sound | Two soft low foot thumps |

All files are 22 050 Hz, 16-bit mono WAV; Godot imports them with QOA
compression, and the two ambience layers loop forward over the whole file.
Listening quality has not been judged by a person yet.
