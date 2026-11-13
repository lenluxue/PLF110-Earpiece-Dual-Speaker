# PLF110 Earpiece/Speaker Stereo v2.5.0

English | [简体中文](README.zh-CN.md) | [Bahasa Indonesia](README.id.md)

![Project image](assets/IMG_20261003_094440.jpg)

KernelSU/Magisk module for the rooted OnePlus PLF110 running ColorOS 16 or 17.

It assigns `AUDIO_DEVICE_OUT_SPEAKER` and `AUDIO_DEVICE_OUT_EARPIECE` to the media
strategy, keeps the earpiece media index linked to the media-volume slider,
and programs the AW88265 smart amplifier to select the right I2S channel. The
module also overlays the active audio policy so the earpiece endpoint stays
stereo; this prevents AudioFlinger from folding left and right before they
reach the two physical outputs.

ColorOS 16 retains the original strategy 5, routing/volume DEX files and policy
contents. ColorOS 17 discovers the `STREAM_MUSIC` strategy at runtime (ID 0 on
PLF110_17.0.0.101) and calls `IAudioService.setDeviceVolume` through the firmware's
Binder stub, instead of a hardcoded transaction number.

At boot, ColorOS 17 policy copies are generated from the current firmware.
Only the earpiece output profile masks change to stereo; other endpoints,
routes, vendor feature lists and spatializer definitions retain their stock
contents. ColorOS 16 uses the existing policy files from `legacy16/`.

The receiver path disables its `ADDA_DL_CH2/CH4 -> DL0_CH2` right-channel
switches, while the bottom AW88265 path keeps `I2SOUT4_CH2 -> DL0_CH2` for the
right channel.

The module uses direct left/right routing and does not request spatialization.

Install the ZIP in KernelSU or Magisk and reboot. The module action button
toggles the dual route without a reboot. Uninstalling clears the route and
restores the earpiece device index saved during the first installation.

The AW88265 channel selection uses the driver's `CHSEL` field in `I2SCTRL1`
(`0x06`): left is `1`, right is `2`. The module saves the original field,
reapplies right while active, and restores the original selection when
disabled or uninstalled. It does not modify the kernel, audio HAL, or vendor
gain tables.

The bottom AW882xx smart amplifier is attenuated independently through its
`aw_dev_0_volume` mixer control. The default value is `128`, which is 16 dB of
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

The test WAV is not included in the module ZIP. It can be generated with
`tools/make_channel_test.c` from the repository.

To tune only media, write a numeric offset to
`/data/adb/plf110_earpiece_dual_speaker/earpiece_offset` and toggle the module
action; the default offset is `0` media steps.

To tune the left/right perceived balance without rebuilding, write an integer
from `0` to `720` to
`/data/adb/plf110_earpiece_dual_speaker/smartpa_attenuation`. Each step lowers
only the bottom speaker by 0.125 dB; for example `24` is -3 dB, `32` is -4 dB,
`40` is -5 dB, `48` is -6 dB, `64` is -8 dB, `80` is -10 dB, `112` is
-14 dB, and `128` is -16 dB. The running monitor applies the new value within
one second.

Build the compact installable ZIP with `sh tools/build.sh`. Repository images
and development tools are excluded. Reboot after installation to load the
generated policy. See `docs/coloros-compatibility.md` in the repository for
the validation scope.

## License

This project is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE).
Some included third-party files retain the license notices included with those files.
