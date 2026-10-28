import unittest

import synth_audio


class SynthAudioTest(unittest.TestCase):
    def test_sounds_are_bounded_and_audible(self):
        for name, build in synth_audio.SOUNDS.items():
            samples = build()
            with self.subTest(name=name):
                self.assertTrue(samples)
                peak = max(abs(s) for s in samples)
                self.assertLessEqual(peak, 1.0)
                self.assertGreater(peak, 0.1)

    def test_ambience_loops_have_different_periods_and_no_seam(self):
        wind = synth_audio.wind_loop()
        birds = synth_audio.bird_loop()
        self.assertEqual(len(wind), 23 * synth_audio.RATE)
        self.assertEqual(len(birds), 19 * synth_audio.RATE)
        # Wrapping from the last sample to the first must look like any other
        # step in the signal, not a click.
        steps = sorted(abs(b - a) for a, b in zip(wind, wind[1:]))
        self.assertLessEqual(abs(wind[0] - wind[-1]), steps[int(len(steps) * 0.999)])
        # Birdsong sits on silence at both ends, so its loop is seamless.
        self.assertLess(abs(birds[0]) + abs(birds[-1]), 1e-6)

    def test_calls_are_short(self):
        for name in ["wolf_howl.wav", "lynx_growl.wav", "boar_grunt.wav", "deer_bark.wav", "fox_yip.wav", "hare_thump.wav"]:
            with self.subTest(name=name):
                self.assertLess(len(synth_audio.SOUNDS[name]()), 3 * synth_audio.RATE)

    def test_generation_is_deterministic(self):
        self.assertEqual(synth_audio.encode(synth_audio.fox_yip()), synth_audio.encode(synth_audio.fox_yip()))
        self.assertEqual(synth_audio.bird_loop()[:5000], synth_audio.bird_loop()[:5000])


if __name__ == "__main__":
    unittest.main()
