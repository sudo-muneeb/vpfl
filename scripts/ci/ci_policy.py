#!/usr/bin/env python3
"""Path selection and fail-closed result validation for the two CI workflows."""
import argparse
import json
import os
from pathlib import Path

JOBS = {'fixtures': 'core', 'quality': 'core', 'native': 'core',
        'package': 'packaging', 'display': 'compatibility',
        'graphical_subtitles': 'subtitles', 'lifecycle_stress': 'stress'}
FLAGS = ('docs_only', 'core', 'compatibility', 'packaging', 'subtitles',
         'desktop', 'stress', 'workflow')


def is_documentation(path):
    return (path.endswith('.md') and (
        '/' not in path or path.startswith(('docs/', '.agents/'))
        or path == '.github/PULL_REQUEST_TEMPLATE.md'))


def classify(paths, *, release=False):
    """Only known low-risk paths narrow coverage; unrecognized paths run full CI."""
    selected = {flag: False for flag in FLAGS}
    selected['workflow'] = any(p.startswith(('.github/', 'scripts/ci/', 'scripts/testing/', 'test/ci/'))
                               and not is_documentation(p) for p in paths)
    selected['docs_only'] = bool(paths) and all(map(is_documentation, paths)) and not release
    if not selected['docs_only']:
        selected['core'] = True
        categories = set()
        for path in paths:
            if is_documentation(path):
                continue
            if path.startswith(('lib/ui/home/', 'lib/ui/library/', 'lib/ui/folders/',
                                'lib/ui/shell/', 'lib/ui/core/themes/', 'test/ui/')):
                categories.add('ui')
                continue
            if path.startswith('lib/ui/core/widgets/'):
                categories.add('desktop')
                selected['desktop'] = True
                continue
            if path.startswith('packaging/'):
                categories.add('packaging')
                selected['packaging'] = True
                selected['compatibility'] = True
                selected['desktop'] = True
                continue
            if path.startswith(('integration_test/subtitle', 'test/fixtures/subtitles/')):
                categories.add('subtitles')
                selected['subtitles'] = True
                continue
            if path.startswith('packages/vpfl_desktop_linux/'):
                categories.add('desktop')
                selected['desktop'] = True
                selected['compatibility'] = True
                selected['packaging'] = True
                continue
            # Playback, shared state, dependencies, renderer, infrastructure,
            # and unknown paths can affect every product surface.
            categories.add('full')
            for flag in ('compatibility', 'packaging', 'subtitles', 'desktop'):
                selected[flag] = True
        if release or not paths or len(categories) > 1:
            for flag in ('compatibility', 'packaging', 'subtitles', 'desktop'):
                selected[flag] = True
    selected['stress'] = release
    return {key: str(value).lower() for key, value in selected.items()}


def validate_gate(needs, *, release=False):
    for job in ('changes', 'commit-messages'):
        if needs.get(job, {}).get('result') != 'success':
            raise ValueError(f'{job} did not succeed')
    outputs = needs['changes'].get('outputs', {})
    if any(outputs.get(flag) not in ('true', 'false') for flag in FLAGS):
        raise ValueError('Missing or invalid classification output')
    if outputs['stress'] != str(release).lower():
        raise ValueError('Lifecycle selection disagrees with invocation mode')
    docs = outputs['docs_only'] == 'true'
    if (outputs['core'] == 'true') == docs:
        raise ValueError('Core and documentation selection disagree')
    if docs and any(outputs[f] != 'false' for f in FLAGS if f != 'docs_only'):
        raise ValueError('Documentation selection contains application checks')
    if outputs['stress'] == 'true' and any(outputs[f] != 'true' for f in
                                          ('core', 'compatibility', 'packaging', 'subtitles', 'desktop')):
        raise ValueError('Release qualification must select every lane')
    for job, flag in JOBS.items():
        expected = 'success' if outputs[flag] == 'true' else 'skipped'
        actual = needs.get(job, {}).get('result')
        if actual != expected:
            raise ValueError(f'{job}: {actual}; expected {expected}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--paths', type=Path, help='NUL-delimited changed files')
    parser.add_argument('--release', action='store_true')
    parser.add_argument('--gate', action='store_true')
    args = parser.parse_args()
    if args.gate:
        needs = json.loads(os.environ['NEEDS_JSON'])
        print(json.dumps(needs, indent=2))
        validate_gate(needs, release=os.environ.get('RELEASE') == 'true')
    else:
        paths = args.paths.read_bytes().decode().split('\0') if args.paths else []
        outputs = classify([p for p in paths if p], release=args.release)
        print(json.dumps(outputs, indent=2))
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            for key, value in outputs.items():
                print(f'{key}={value}', file=output)


if __name__ == '__main__':
    main()
