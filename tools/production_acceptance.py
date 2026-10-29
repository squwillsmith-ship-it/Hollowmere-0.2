#!/usr/bin/env python3
"""Prepare Step44/45 acceptance evidence without pretending to run Godot.

prepare: preflight available source and emit a practical, pinned QA matrix.
review: inspect REAL renderer PNGs produced by tools/test_environment.py render.
Neither command substitutes for a human assessment of game visuals/audio or Windows QA.
No network or GitHub Actions needed. Uses stdlib; Pillow only for optional montage.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
VIEWPOINTS = (
    ('well', 'subterranean stone and view into well'),
    ('mine', 'entrance, depth, irregular stone and usable access'),
    ('undercroft', 'usable interior camera view without ceiling occlusion'),
    ('bell', 'protected bell, weathered masonry, readable silhouette'),
    ('harbour', 'coastal terrain, usable landing and abandoned quay'),
    ('headland', 'non-blockout cliff/roads and visual silhouette'),
    ('inn', 'weathered pitched roof and genuinely open doorway'),
    ('mine_office', 'distinct gabled office and individually removable parts'),
    ('chapel', 'story architecture and restrained atmosphere'),
    ('shore', 'foreshore texture and water/rock transition'),
)
BASELINE_GROUPS = {
    'step06-engine-frame.png': 'engine framebuffer smoke',
    'reference-cottage.png': 'cottage construction and surface breakup',
    'reference-warehouse.png': 'warehouse construction and layered removal',
}
SUITE_MARKERS = {
    'test_step44.gd': 'HOLLOWMERE_STEP44_TEST_OK',
    'test_landmark_components.gd': 'HOLLOWMERE_LANDMARK_COMPONENTS_OK',
    'test_phase_ef_first_person.gd': 'HOLLOWMERE_FIRST_PERSON_TARGET_QA_OK',
    'test_phase_ef_player_motion.gd': 'HOLLOWMERE_PLAYER_ROUTE_MOTION_OK',
    'test_campaign_four_acts.gd': 'HOLLOWMERE_FOUR_ACTS_TRANSACTION_OK',
    'test_phase_g.gd': 'HOLLOWMERE_PHASE_G_TEST_OK',
    'test_step45_save_recovery.gd': 'HOLLOWMERE_STEP45_RECOVERY_OK',
}


def source_ref() -> str:
    # A verified GitHub checkout exposes its exact code commit via GITHUB_SHA.
    # A local extracted ZIP can have modified bytes: do not call its old SHA current.
    env = os.environ.get('GITHUB_SHA', '')
    return env if re.fullmatch(r'[a-f0-9]{40}', env) else 'UNPINNED_LOCAL_SOURCE'


def capture_specs() -> list[dict[str, str]]:
    return [{'file': f'phase-e-{key}.png', 'viewpoint': key, 'inspect': label}
            for key, label in VIEWPOINTS]


def runner_assertions() -> list[str]:
    runner = (ROOT / 'tools/test_environment.py').read_text(encoding='utf-8')
    missing = []
    for filename, marker in SUITE_MARKERS.items():
        path = ROOT / 'game/tests' / filename
        if not path.is_file() or marker not in path.read_text(encoding='utf-8'):
            missing.append(f'Missing test/marker: {filename} / {marker}')
        if filename not in runner:
            missing.append(f'Not registered for exact Godot check: {filename}')
    for name, _ in VIEWPOINTS:
        if name not in (ROOT / 'game/tests/test_phase_e_capture.gd').read_text(encoding='utf-8'):
            missing.append(f'Capture viewpoint missing from GDScript: {name}')
    if 'HOLLOWMERE_UNDERGROUND_RENDER_DIR' not in runner:
        missing.append('Actual Forward+/Vulkan screenshot capture not configured')
    return missing


def write_report(filename: str, data: dict) -> Path:
    BUILD.mkdir(exist_ok=True)
    destination = BUILD / filename
    destination.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    return destination


def prepare() -> tuple[dict, int]:
    missing = runner_assertions()
    report = {
        'source_provenance': source_ref(),
        'tested_with_godot': False,
        'tested_on_native_windows': False,
        'human_visual_signoff': False,
        'human_audio_signoff': False,
        'full_player_campaign_signoff': False,
        'offline_wiring_errors': missing,
        'viewpoints': capture_specs(),
        'engine_commands': [
            'python tools/test_environment.py check --godot <pinned-4.7.2-editor>',
            'python tools/test_environment.py render --godot <pinned-4.7.2-editor>',
            'python tools/production_acceptance.py review --frames-dir build',
        ],
        'windows_gui_test': 'Owner-deferred to roadmap Step47; absolutely required before Step48',
        'manual_review_required': [
            'Inspect ten actual, source-matched frames; identify blockout materials and excessive uniformity',
            'Confirm sound design by listening to five player-operated tools, impact/release, ambience, cues',
            'Navigate a real first-person four-act playthrough and both endings, including save/reload',
            'Verify actual salvage carrying, interaction reach, blocked support removal and physical recovery',
            'Approve numerical balance only after play sessions; do not silently edit provisional tables',
        ],
    }
    dest = write_report('qa-acceptance-preflight.json', report)
    lines = [
        '# Hollowmere production acceptance — not yet signed off', '',
        f'Source: `{report["source_provenance"]}` (unverified when local).',
        'This report prepares tests; it does NOT claim any Godot or native Windows run.', '',
        '## Camera evidence to inspect', '',
    ]
    for entry in capture_specs():
        lines.append(f'- [ ] `{entry["file"]}`: {entry["inspect"]}')
    lines += ['', '## Required human acceptance checks', '']
    lines += [f'- [ ] {v}' for v in report['manual_review_required']]
    lines += ['', '## Exact QA commands (when available)', '']
    lines += [f'- `{s}`' for s in report['engine_commands']]
    lines += ['', '## Source preflight issues', '']
    lines += [f'- {s}' for s in missing] if missing else ['- None detected. Engine parsing remains untested.']
    (BUILD / 'qa-visual-review-checklist.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('Preflight:', dest, 'wiring problems:', len(missing), 'engine tested: NO')
    return report, 1 if missing else 0


def png_metadata(path: Path) -> dict:
    with path.open('rb') as fh:
        header = fh.read(24)
    if len(header) < 24 or not header.startswith(b'\x89PNG\r\n\x1a\n') or header[12:16] != b'IHDR':
        raise ValueError('Not a PNG with an IHDR header')
    width, height = struct.unpack('>II', header[16:24])
    if width < 640 or height < 360:
        raise ValueError('Framebuffer dimensions below minimum 640x360')
    if path.stat().st_size < 10_000:
        raise ValueError('PNG too small to substantiate full-frame screenshot')
    try:
        from PIL import Image
    except ImportError as exc:
        raise ValueError('Pillow required to decode and inspect screenshot pixels') from exc
    try:
        with Image.open(path) as frame:
            frame.load()  # CRC/decode path; header-only files are not accepted.
            if frame.size != (width, height):
                raise ValueError('Pixel dimensions differ from PNG header')
            reduced = frame.convert('RGB').resize((32, 18))
            palette = len(set(reduced.get_flattened_data()))
            if palette < 12:
                raise ValueError('Blank or uniform frame: insufficient pixel variation')
    except (OSError, SyntaxError) as exc:
        raise ValueError(f'PNG could not be decoded: {exc}') from exc
    return {'width': width, 'height': height, 'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def inspect_frames(folder: Path) -> tuple[dict, int]:
    statuses = {}
    digests = {}
    problems = []
    for spec in capture_specs():
        filename = spec['file']
        path = folder / filename
        if not path.is_file():
            problems.append(f'NO FRAME: {filename}')
            statuses[filename] = {'status': 'MISSING'}
            continue
        try:
            metadata = png_metadata(path)
        except (OSError, ValueError) as exc:
            problems.append(f'INVALID FRAME: {filename}: {exc}')
            statuses[filename] = {'status': 'INVALID', 'reason': str(exc)}
            continue
        if metadata['sha256'] in digests:
            problems.append(f'DUPLICATED PIXEL FILE: {filename} and {digests[metadata["sha256"]]}')
        else:
            digests[metadata['sha256']] = filename
        statuses[filename] = {'status': 'IMAGE_PRESENT_UNREVIEWED', **metadata}
    report = {
        'source_provenance': source_ref(), 'frames_folder': str(folder),
        'frames': statuses, 'errors': problems,
        'frames_exist_and_are_structurally_valid': not problems,
        'human_visual_signoff': False,
        'technical_godot_pass_from_images_alone': False,
        'native_windows_signoff': False,
    }
    return report, 2 if problems else 0


def review(folder: Path) -> int:
    report, result = inspect_frames(folder)
    dest = write_report('qa-visual-evidence.json', report)
    print('Evidence:', dest, 'frames:', len(report['frames']),
          'problems:', len(report['errors']), 'human signoff: PENDING')
    for message in report['errors']:
        print(' - ' + message, file=sys.stderr)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'review'])
    parser.add_argument('--frames-dir', type=Path, default=BUILD)
    args = parser.parse_args()
    if args.action == 'prepare':
        return prepare()[1]
    return review(args.frames_dir)


if __name__ == '__main__':
    sys.exit(main())