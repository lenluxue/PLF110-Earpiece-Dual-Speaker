# PLF110 Earpiece/Speaker Stereo v2.1.0

English | [简体中文](README.zh-CN.md) | [Bahasa Indonesia](README.id.md)

KernelSU/Magisk module for the rooted OnePlus PLF110 Android 16 firmware.

It assigns `AUDIO_DEVICE_OUT_SPEAKER` and `AUDIO_DEVICE_OUT_EARPIECE` to media
strategy 5, keeps the earpiece media index linked to the media-volume slider,
and programs the AW88265 smart amplifier to select the right I2S channel. The
receiver remains on the stock mono handset path. The included test tone checks
whether this firmware feeds that path from the left channel or folds both
channels to mono. This is a channel-separation test, not a virtual surround
effect.

Install the ZIP in KernelSU or Magisk and reboot. The module action button
toggles the dual route without a reboot. Uninstalling clears the route and
restores the earpiece device index saved during the first installation.

The AW88265 channel selection uses the driver's `CHSEL` field in `I2SCTRL1`
(`0x06`): left is `1`, right is `2`. The module saves the original field,
reapplies right while active, and restores the original selection when
disabled or uninstalled. It does not modify the kernel, audio HAL, or vendor
gain tables.

The bottom AW882xx smart amplifier is attenuated independently through its
`aw_dev_0_volume` mixer control. The default value is `96`, which is 12 dB of
attenuation because the AW88265 driver uses 0.125 dB steps (`0` is the loudest
setting). The monitor reapplies this value if the audio HAL changes profiles.
The earpiece uses the vendor `Handset Volume` maximum safe index
(`0`) while enabled. The latter control is shared with calls and voice-message
playback, so those paths may also be louder. Disabling or uninstalling restores
the saved mixer values when they are valid for the hardware control.

Gain-table modification remains disabled on this firmware because the MediaTek
HAL crashes when it reloads a modified table. The module leaves the stock gain
tables in place.

Play `左右声道测试.wav` at a low media volume. The first 440 Hz tone is left;
the following 880 Hz tone is right. For separated output, the first tone should
come from the earpiece and the second from the bottom speaker. If the earpiece
also plays the second tone, its HAL route is folding stereo to mono and needs a
separate HAL/policy change.

To tune only media, write a numeric offset to
`/data/adb/plf110_earpiece_dual_speaker/earpiece_offset` and toggle the module
action; the default offset is `160` media steps.

To tune the left/right perceived balance without rebuilding, write an integer
from `0` to `720` to
`/data/adb/plf110_earpiece_dual_speaker/smartpa_attenuation`. Each step lowers
only the bottom speaker by 0.125 dB; for example `24` is -3 dB, `32` is -4 dB,
`40` is -5 dB, `48` is -6 dB, `64` is -8 dB, `80` is -10 dB, and `96` is
-12 dB. The running monitor applies the new value within one second.
