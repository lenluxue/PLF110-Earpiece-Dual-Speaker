# ColorOS 16 / 17 compatibility validation

Version: 2.5.1, versionCode 251. Validated on 2026-11-14.

## Implementation

- ColorOS detection prefers `ro.build.version.oplusrom`, then `ro.build.version.opporom`; Android SDK 36/37 is used only when ROM version properties are absent.
- ColorOS 16 uses the original strategy 5 and the existing `strategy_route.dex` and `device_volume.dex`. Mixer tools, policy and feature files are unchanged from repository commit `7b5047a`.
- Legacy configuration is stored in `legacy16/` and bound to the original partition paths only on ColorOS 16. No policy/feature directories sit at the module root where they could mount automatically on another OS version.
- ColorOS 17 queries the product strategy associated with `STREAM_MUSIC`. It does not clear strategy 0 as a legacy override. Device volume uses the current firmware's `IAudioService$Stub.asInterface` and `setDeviceVolume` signature.
- ColorOS 17 copies the current firmware's earpiece policy files on each boot and changes only earpiece output `channelMasks` to stereo. Other attributes, routes, endpoints, feature lists and spatializer declarations remain unchanged. Missing or unsupported earpiece profiles fail preparation without mounting partial output.
- Default attenuation remains 128 driver steps (-16 dB), and the default media offset remains 0.
- The install ZIP excludes repository images, test artifacts and development tools.
- The eight runtime helpers are grouped in `bin/`, with all entrypoint references and installation permissions updated.

## 2.5.1 startup fix

The installed 2.5.0 boot log reported `Cannot list audio strategies: -6` after loading the stereo earpiece policy. Its initial status check exited before the apply retry loop. The same installed helper returned `0 160` after boot, confirming the startup query was transient.

ColorOS 17 now continues after an unsuccessful initial status query and retries the complete apply up to 24 times at five-second intervals. Disabling the route during that wait stops retries. ColorOS 16 retains its previous initialization behavior and six-apply retry limit.

A full live apply was tested using an isolated copy and state directory while the installed stereo policy was active: route status 0, bottom attenuation 128, AW88265 register 0x06 readback 0x38e8, and earpiece volume synchronized to speaker index 30. The clear operation restored the original volume 43, amplifier selection and saved mixer values. The user's action-disabled marker was preserved. Audio service PIDs stayed 8424 and 8440 during this test.

## ColorOS 17 device evidence

Device: PLF110 / OP60F9L1. Build: `PLF110_17.0.0.101(CN01)`. ROM: `V17.0.0`. Android 17 / SDK 37.

- Media strategy discovery: `0`; current music maximum: `160`.
- Active policy source: `/my_product/etc/audio_policy_configuration_a2dp_offload_enable_cg_enable.xml`.
- Current firmware's six matching policy configurations were generated and compared as XML. Only earpiece profile masks changed; the active configuration differs in exactly its two earpiece masks.
- Hardware queries succeeded for `Handset Volume`, `aw_dev_0_volume`, `ADDA_DL_CH2 DL0_CH2`, `ADDA_DL_CH4 DL0_CH2` and AW88265 register 0x06.
- Device-volume smoke test set the earpiece index from 43 to 42 and read back 42 through `IAudioService`.
- Native strategy route returned status 0 and exposed both speaker and earpiece in strategy 0's preferred devices.
- The new helper's route-clear operation removed those two preferred endpoints successfully.
- The original preferred devices (empty) and original earpiece index 43 were restored after the smoke test.
- `audioserver` and `android.hardware.audio.service.mediatek` retained PIDs 7960 and 7977 throughout the test.

## Regression checks

`python -m unittest discover -s tests -v` passes 15 checks:

- Current ColorOS 17 XML contents, targeted modifications and idempotence.
- XML comments, single-quoted attributes and same-line elements.
- Rejection of missing, unsupported and unclosed earpiece profiles.
- Byte equality of all original ColorOS 16 policy/feature files and four original binary tools.
- ROM-property precedence and SDK fallback.
- ColorOS 16 route/volume helper command sequences match the baseline.
- ColorOS 16 mounts the original files at the correct partition paths.
- ColorOS 17 does not clear the media strategy as a legacy override.
- Recovery from an initial strategy-query failure and subsequent transient apply failures.
- Bounded retries on persistent failure and honoring disable during a retry.
- Unchanged ColorOS 16 initialization behavior and six-apply retry limit; preservation of an existing action-disabled state.

Shell syntax validation and ZIP integrity checks also pass. The production Android `/system/bin/awk` generated the same output as the test implementation on the current active policy.

## Validation limits

The current phone runs ColorOS 17. ColorOS 16 has source, binary and command-path regression coverage; a fresh ColorOS 16 boot was not performed. ColorOS 17 live routing and volume interfaces were tested, but the generated stereo policy requires installation and a reboot before channel separation can be verified audibly. No audio-server restart or phone reboot was performed by the agent.

The local 2.5.1 build has not been published to GitHub. `update.json` continues describing the existing published 2.4.7 release until a release is published.
