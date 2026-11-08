"""Observable CI selection and gate contracts, including bad upstream results."""
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'ci_policy', Path(__file__).resolve().parents[2] / 'scripts/ci/ci_policy.py')
policy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(policy)


class SelectionTest(unittest.TestCase):
    def test_documentation_allowlist_and_boundaries(self):
        for path in ('README.md', 'docs/ci/README.md', '.agents/llm.md',
                     '.github/PULL_REQUEST_TEMPLATE.md'):
            self.assertEqual(policy.classify([path])['docs_only'], 'true')
        for paths in ([], ['docs/fixture.json'], ['packages/plugin/README.md'],
                      ['README.md', 'unknown'], ['lib/new.dart']):
            self.assertEqual(policy.classify(paths)['compatibility'], 'true')

    def test_ui_and_component_dependencies(self):
        ui = policy.classify(['lib/ui/home/home_screen.dart'])
        self.assertEqual(ui['core'], 'true')
        self.assertEqual(ui['subtitles'], 'false')
        self.assertEqual(ui['compatibility'], 'false')
        for path in ('lib/data/services/playback_service.dart',
                     'lib/ui/player/player_screen.dart', 'pubspec.lock',
                     'third_party/media_kit_video/linux/video_output.cc',
                     'scripts/ci/run_display.sh', '.github/workflows/ci.yml'):
            result = policy.classify([path])
            self.assertEqual(result['compatibility'], 'true', path)
            self.assertEqual(result['subtitles'], 'true', path)
        self.assertEqual(policy.classify(['lib/ui/core/widgets/app_top_bar.dart'])['desktop'], 'true')
        self.assertEqual(policy.classify(['packaging/arch/PKGBUILD'])['packaging'], 'true')
        self.assertEqual(policy.classify(['integration_test/subtitle_delay_linux_test.dart'])['subtitles'], 'true')
        self.assertEqual(policy.classify(['test/fixtures/subtitles/sources/english.srt'])['subtitles'], 'true')
        self.assertEqual(policy.classify(['.github/actionlint.yaml'])['workflow'], 'true')
        self.assertEqual(policy.classify(['scripts/testing/test_gpu.sh'])['workflow'], 'true')

    def test_mixed_and_release(self):
        mixed = policy.classify(['lib/ui/home/home_screen.dart',
                                 'integration_test/subtitle_delay_linux_test.dart'])
        for flag in ('compatibility', 'packaging', 'subtitles', 'desktop'):
            self.assertEqual(mixed[flag], 'true')
        self.assertEqual(policy.classify(['README.md', 'lib/ui/home/home_screen.dart'])['subtitles'], 'false')
        self.assertEqual(policy.classify(['lib/ui/home/home_screen.dart', 'unknown'])['subtitles'], 'true')
        self.assertEqual(policy.classify(['README.md'], release=True)['stress'], 'true')
        self.assertEqual(policy.classify(['README.md'], release=True)['docs_only'], 'false')


class GateTest(unittest.TestCase):
    def needs(self, paths, release=False):
        selection = policy.classify(paths, release=release)
        needs = {'changes': {'result': 'success', 'outputs': selection},
                 'commit-messages': {'result': 'success'}}
        needs.update({job: {'result': 'success' if selection[flag] == 'true' else 'skipped'}
                      for job, flag in {
                          'fixtures': 'core', 'quality': 'core', 'native': 'core',
                          'package': 'packaging', 'display': 'compatibility',
                          'graphical_subtitles': 'subtitles',
                          'lifecycle_stress': 'stress'}.items()})
        return needs

    def test_expected_results(self):
        for paths in (['README.md'], ['lib/ui/home/home_screen.dart'], ['unknown']):
            policy.validate_gate(self.needs(paths))
        policy.validate_gate(self.needs(['README.md'], release=True), release=True)

    def test_fail_closed_for_every_job_and_result(self):
        for paths in (['README.md'], ['unknown']):
            for job in self.needs(paths):
                for result in ('failure', 'cancelled', 'skipped', 'success', ''):
                    needs = self.needs(paths)
                    if needs[job]['result'] == result:
                        continue
                    needs[job]['result'] = result
                    with self.subTest(paths=paths, job=job, result=result):
                        with self.assertRaises(ValueError):
                            policy.validate_gate(needs)

    def test_missing_required_job_is_not_verification(self):
        for job in self.needs(['unknown']):
            needs = self.needs(['unknown'])
            del needs[job]
            with self.subTest(job=job):
                with self.assertRaises(ValueError):
                    policy.validate_gate(needs)

    def test_release_cannot_accept_pr_selection(self):
        with self.assertRaises(ValueError):
            policy.validate_gate(self.needs(['README.md']), release=True)
        with self.assertRaises(ValueError):
            policy.validate_gate(self.needs(['unknown']), release=True)
        needs = self.needs(['unknown'], release=True)
        needs['changes']['outputs']['subtitles'] = 'false'
        needs['graphical_subtitles']['result'] = 'skipped'
        with self.assertRaises(ValueError):
            policy.validate_gate(needs, release=True)

    def test_invalid_and_inconsistent_selection(self):
        for key in policy.classify(['unknown']):
            for value in (None, '', 'TRUE', 'false' if key == 'core' else 'bogus'):
                needs = self.needs(['unknown'])
                needs['changes']['outputs'][key] = value
                with self.assertRaises(ValueError):
                    policy.validate_gate(needs)
        needs = self.needs(['README.md'])
        needs['changes']['outputs']['subtitles'] = 'true'
        with self.assertRaises(ValueError):
            policy.validate_gate(needs)


if __name__ == '__main__':
    unittest.main()
