import os
from pathlib import Path
import subprocess
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT.parent / 'plf110-remote'


def patch_xml(source):
    return subprocess.run(['awk', '-f', str(ROOT / 'patch_earpiece.awk')],
                          input=source, text=True, capture_output=True)


class PolicyTests(unittest.TestCase):
    def assert_only_earpiece_changed(self, source):
        result = patch_xml(source)
        self.assertEqual(result.returncode, 0, result.stderr)
        before, after = ET.fromstring(source), ET.fromstring(result.stdout)
        endpoints = before.findall('.//devicePort')
        for port in endpoints:
            if port.get('type') == 'AUDIO_DEVICE_OUT_EARPIECE' and port.get('role') == 'sink':
                for profile in port.findall('profile'):
                    profile.set('channelMasks', 'AUDIO_CHANNEL_OUT_STEREO')
        self.assertEqual(ET.tostring(before), ET.tostring(after))
        self.assertEqual(patch_xml(result.stdout).stdout, result.stdout)

    def test_current_coloros17_policies(self):
        generated = ROOT / '.diagnostics/generated17'
        files = list(generated.rglob('*.xml'))
        self.assertGreaterEqual(len(files), 2)
        for file in files:
            stock = Path('/') / file.relative_to(generated)
            source = stock.read_text()
            self.assert_only_earpiece_changed(source)
            self.assertEqual(file.read_text(), patch_xml(source).stdout)

    def test_comments_single_quotes_and_same_line_elements(self):
        source = '''<root><!-- <devicePort type="AUDIO_DEVICE_OUT_EARPIECE" role="sink"><profile channelMasks="AUDIO_CHANNEL_OUT_MONO"/></devicePort> -->
<devicePort role = 'sink' type = 'AUDIO_DEVICE_OUT_EARPIECE' tagName='Receiver'><profile name='AUDIO_CHANNEL_OUT_MONO' channelMasks = 'AUDIO_CHANNEL_OUT_MONO'/><profile channelMasks='AUDIO_CHANNEL_OUT_MONO'/></devicePort>
<devicePort type="AUDIO_DEVICE_OUT_TELEPHONY_TX" role="sink"><profile channelMasks="AUDIO_CHANNEL_OUT_MONO"/></devicePort></root>
'''
        self.assert_only_earpiece_changed(source)
        self.assertIn('<!-- <devicePort', patch_xml(source).stdout)
        self.assertIn('<profile channelMasks="AUDIO_CHANNEL_OUT_MONO"/></devicePort> -->', patch_xml(source).stdout)

    def test_invalid_endpoint_is_rejected(self):
        for source in (
            '<root/>\n',
            '<root><devicePort type="AUDIO_DEVICE_OUT_EARPIECE" role="sink"><profile channelMasks="dynamic"/></devicePort></root>\n',
            '<root><devicePort type="AUDIO_DEVICE_OUT_EARPIECE" role="sink"><profile channelMasks="AUDIO_CHANNEL_OUT_MONO"/></root>\n',
            '<root><!-- unfinished\n',
        ):
            self.assertNotEqual(patch_xml(source).returncode, 0)
            self.assertEqual(patch_xml(source).stdout, '')

    def test_legacy_files_are_identical(self):
        for file in (ROOT / 'legacy16').rglob('*.xml'):
            original = BASELINE / file.relative_to(ROOT / 'legacy16')
            self.assertEqual(file.read_bytes(), original.read_bytes(), str(file))
        for name in ('strategy_route.dex', 'device_volume.dex', 'mixer_set_int', 'mixer_set_route'):
            self.assertEqual((ROOT / name).read_bytes(), (BASELINE / name).read_bytes(), name)


class VersionTests(unittest.TestCase):
    def detect(self, rom, sdk):
        code = '''getprop() { case "$1" in ro.build.version.oplusrom) echo "$TEST_ROM";; ro.build.version.sdk) echo "$TEST_SDK";; esac; }; . ./coloros_compat.sh; coloros_major'''
        env = dict(os.environ, TEST_ROM=rom, TEST_SDK=str(sdk))
        return subprocess.check_output(['sh', '-c', code], cwd=ROOT, env=env, text=True).strip()

    def test_rom_property_takes_precedence(self):
        self.assertEqual(self.detect('V16.0.0', 37), '16')
        self.assertEqual(self.detect('V17.0.0', 36), '17')

    def test_sdk_fallback(self):
        self.assertEqual(self.detect('', 36), '16')
        self.assertEqual(self.detect('', 37), '17')
        self.assertEqual(self.detect('', 35), 'unsupported')
        self.assertEqual(self.detect('V18.0.0', 37), 'unsupported')

    def test_coloros16_helper_calls_match_baseline(self):
        calls = '''
COLOROS_MAJOR=16
APP_PROCESS=mock_app
mock_app() { printf '%s:' "$CLASSPATH"; printf ' %s' "$@"; printf '\\n'; }
run_compat17() { echo 'unexpected ColorOS 17 helper'; return 1; }
run_route keep
clear_legacy_route
set_earpiece_volume 43
'''
        def trace(path):
            source = path.read_text().split('case "$1" in\n    apply)')[0]
            source = source.split('\ninit_audio_compat || exit 1')[0]
            return subprocess.check_output(['sh', '-c', source + calls, str(ROOT / 'audio_ctl.sh')], text=True)
        self.assertEqual(trace(ROOT / 'audio_ctl.sh'), trace(BASELINE / 'audio_ctl.sh'))

    def test_coloros17_does_not_clear_media_as_legacy(self):
        source = (ROOT / 'audio_ctl.sh').read_text().split('\ninit_audio_compat || exit 1')[0]
        calls = '''
COLOROS_MAJOR=17
MEDIA_STRATEGY_ID=0
run_compat17() { printf '%s\\n' "$*"; }
clear_legacy_route
run_route keep
set_earpiece_volume 20
'''
        result = subprocess.check_output(['sh', '-c', source + calls, str(ROOT / 'audio_ctl.sh')], text=True)
        self.assertEqual(result, 'route 0 keep\nset 1 20\n')

    def test_coloros16_mounts_only_legacy_files(self):
        code = '''
getprop() { echo V16.0.0; }
mount() { printf '%s\\n' "$3"; }
PLF110_POLICY_NS=1
. ./post-fs-data.sh
'''
        result = subprocess.check_output(['sh', '-c', code, str(ROOT / 'post-fs-data.sh')], cwd=ROOT, text=True)
        expected = {'/' + str(p.relative_to(ROOT / 'legacy16')) for p in (ROOT / 'legacy16').rglob('*.xml')}
        self.assertEqual(set(result.splitlines()), expected)


if __name__ == '__main__':
    unittest.main(verbosity=2)
