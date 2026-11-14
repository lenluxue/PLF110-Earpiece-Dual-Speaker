import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StartupTests(unittest.TestCase):
    def service(self, rom, failures, disable_on_retry=False,
                early_status_failure=True, initially_disabled=False):
        with tempfile.TemporaryDirectory() as temp:
            state = Path(temp)
            if initially_disabled:
                (state / 'disabled').touch()
            source = (ROOT / 'service.sh').read_text().replace(
                'STATE_DIR=/data/adb/plf110_earpiece_dual_speaker',
                'STATE_DIR="$TEST_STATE"')
            # Emulate AudioService present, boot complete, but AudioPolicy not
            # ready during initial status and the first apply attempts.
            mocks = r'''
getprop() {
    case "$1" in sys.boot_completed) echo 1;; *) echo "$TEST_ROM";; esac
}
sleep() { :; }
sh() {
    if [ "$1" = "$BINDIR/patch_gain.sh" ]; then return 0; fi
    printf '%s\n' "$2" >> "$TEST_STATE/calls"
    case "$2" in
        status) [ "$TEST_STATUS_FAIL" = 0 ] ;;
        apply)
            call_count=$((call_count + 1))
            if [ "$TEST_DISABLE" = 1 ]; then touch "$TEST_STATE/disabled"; fi
            [ "$call_count" -gt "$TEST_FAILURES" ]
            ;;
        *) return 0 ;;
    esac
}
call_count=0
'''
            env = dict(os.environ, TEST_STATE=str(state), TEST_ROM=rom,
                       TEST_FAILURES=str(failures), TEST_DISABLE='1' if disable_on_retry else '0',
                       TEST_STATUS_FAIL='1' if early_status_failure else '0')
            result = subprocess.run(['sh', '-c', mocks + source, str(ROOT / 'service.sh')],
                                    env=env, capture_output=True, text=True, timeout=10)
            calls = (state / 'calls').read_text().splitlines()
            return result.returncode, calls, (state / 'service.log').read_text()

    def test_coloros17_recovers_from_early_strategy_failure(self):
        status, calls, log = self.service('V17.0.0', 2)
        self.assertEqual(status, 0, log)
        self.assertEqual(calls, ['status', 'apply', 'apply', 'apply', 'monitor'])
        self.assertIn('audio strategy query not ready', log)
        self.assertIn('stereo route active', log)

    def test_coloros17_gives_up_after_bounded_retries(self):
        status, calls, log = self.service('V17.0.0', 100)
        self.assertEqual(status, 1, log)
        self.assertEqual(calls.count('apply'), 24)
        self.assertNotIn('monitor', calls)
        self.assertIn('failed after 24 attempts', log)

    def test_coloros17_respects_disable_during_retry(self):
        status, calls, log = self.service('V17.0.0', 100, disable_on_retry=True)
        self.assertEqual(status, 0, log)
        self.assertEqual(calls, ['status', 'apply', 'clear'])
        self.assertIn('disabled while waiting', log)

    def test_coloros16_retains_previous_initialization_behavior(self):
        status, calls, log = self.service('V16.0.0', 2)
        self.assertEqual(status, 1, log)
        self.assertEqual(calls, ['status'])
        self.assertNotIn('apply attempt', log)

    def test_coloros16_retains_six_apply_retry_limit(self):
        status, calls, log = self.service('V16.0.0', 100, early_status_failure=False)
        self.assertEqual(status, 1, log)
        self.assertEqual(calls.count('apply'), 6)
        self.assertNotIn('monitor', calls)

    def test_existing_disabled_state_is_preserved(self):
        status, calls, log = self.service('V17.0.0', 2, initially_disabled=True)
        self.assertEqual(status, 0, log)
        self.assertEqual(calls, ['clear'])
        self.assertIn('disabled by action button', log)


if __name__ == '__main__':
    unittest.main(verbosity=2)
