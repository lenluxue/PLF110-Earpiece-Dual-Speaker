# PLF110 Earpiece/Speaker Stereo v2.4.6

English | [简体中文](README.zh-CN.md) | [Bahasa Indonesia](README.id.md)

![Project image](assets/IMG_20261003_094440.jpg)

KernelSU/Magisk module for the rooted OnePlus PLF110 Android 16 firmware.

It assigns `AUDIO_DEVICE_OUT_SPEAKER` and `AUDIO_DEVICE_OUT_EARPIECE` to media
strategy 5, keeps the earpiece media index linked to the media-volume slider,
and programs the AW88265 smart amplifier to select the right I2S channel. The
module also overlays the active audio policy so the earpiece endpoint stays
stereo; this prevents AudioFlinger from folding left and right before they
reach the two physical outputs.

The firmware's Oplus spatializer libraries are present, but this device's
vendor spatializer crashes the MediaTek audio HAL when enabled. This version
keeps the spatializer disabled for stability and uses direct stereo routing.

The receiver path disables its `ADDA_DL_CH2/CH4 -> DL0_CH2` right-channel
switches, while the bottom AW88265 path keeps `I2SOUT4_CH2 -> DL0_CH2` for the
right channel.

The module intentionally does not enable the vendor spatializer. This is
separate from left/right channel separation, which remains active.

Install the ZIP in KernelSU or Magisk and reboot. The module action button
toggles the dual route without a reboot. Uninstalling clears the route and
restores the earpiece device index saved during the first installation.

The AW88265 channel selection uses the driver's `CHSEL` field in `I2SCTRL1`
(`0x06`): left is `1`, right is `2`. The module saves the original field,
reapplies right while active, and restores the original selection when
disabled or uninstalled. It does not modify the kernel, audio HAL, or vendor
gain tables.

The bottom AW882xx smart amplifier is attenuated independently through its
`aw_dev_0_volume` mixer control. The default value is `112`, which is 14 dB of
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
come from the earpiece and the second from the bottom speaker.

To tune only media, write a numeric offset to
`/data/adb/plf110_earpiece_dual_speaker/earpiece_offset` and toggle the module
action; the default offset is `0` media steps.

To tune the left/right perceived balance without rebuilding, write an integer
from `0` to `720` to
`/data/adb/plf110_earpiece_dual_speaker/smartpa_attenuation`. Each step lowers
only the bottom speaker by 0.125 dB; for example `24` is -3 dB, `32` is -4 dB,
`40` is -5 dB, `48` is -6 dB, `64` is -8 dB, `80` is -10 dB, and `112` is
-14 dB. The running monitor applies the new value within one second.
