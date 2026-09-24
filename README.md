# PLF110 Earpiece Dual Speaker v2.0.6

KernelSU/Magisk module tested on the OnePlus PLF110 Android 16 firmware.

It assigns both `AUDIO_DEVICE_OUT_SPEAKER` and
`AUDIO_DEVICE_OUT_EARPIECE` to the current media product strategy (strategy 5
on this Android 16 firmware). The earpiece media
indices are kept linked, so changing the media volume changes both outputs
together. The earpiece is held at the hardware media maximum (index 160) to
compensate for the remaining perceived speaker loudness.

Install the ZIP in KernelSU or Magisk and reboot. The module action button
toggles the dual route without a reboot. Uninstalling clears the route and
restores the earpiece device index saved during the first installation.

The bottom AW882xx smart amplifier is attenuated independently through its
`aw_dev_0_volume` mixer control. The default value is `96`, which is 12 dB of
attenuation because the AW88265 driver uses 0.125 dB steps (`0` is the loudest
setting). The monitor reapplies this value if the audio HAL changes profiles.
The earpiece uses the vendor `Handset Volume` maximum safe index
(`0`) while enabled. The latter control is shared with calls and voice-message
playback, so those paths may also be louder. Disabling or uninstalling restores
the saved mixer values when they are valid for the hardware control.

Gain-table modification is disabled on this firmware: the MediaTek HAL crashes
when it reloads the modified table. The module leaves the stock gain tables in
place and adjusts balance only with live device-volume and AW882xx controls.

To tune only media, write a numeric offset to
`/data/adb/plf110_earpiece_dual_speaker/earpiece_offset` and toggle the module
action; the default offset is `160` media steps.

To tune the left/right perceived balance without rebuilding, write an integer
from `0` to `720` to
`/data/adb/plf110_earpiece_dual_speaker/smartpa_attenuation`. Each step lowers
only the bottom speaker by 0.125 dB; for example `24` is -3 dB, `32` is -4 dB,
`40` is -5 dB, `48` is -6 dB, `64` is -8 dB, `80` is -10 dB, and `96` is
-12 dB. The running monitor applies the new value within one second.
