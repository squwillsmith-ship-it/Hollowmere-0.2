#!/usr/bin/env python3
"""Hollowmere self-contained QA runner. Never reports Godot success without running Godot.

Optional auto-install uses the official version-pinned Linux standard editor archive;
SHA-256 is fixed to the official GitHub 4.7.2 release asset digest.
Usage:
  python tools/test_environment.py doctor
  python tools/test_environment.py check --install
  python tools/test_environment.py check --godot /path/to/godot
  python tools/test_environment.py render --godot /path/to/godot
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
ENGINE_DIR = ROOT / '.qa-tools'
VERSION = (ROOT / 'engine-version.txt').read_text().strip()
ASSET = 'Godot_v4.7.2-stable_linux.x86_64.zip'
ENGINE_ARCHIVE = ENGINE_DIR / ASSET
EXPECTED_SHA256 = 'cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4'
DOWNLOAD_URL = f'https://github.com/godotengine/godot/releases/download/4.7.2-stable/{ASSET}'
REPORT = BUILD / 'qa-environment.json'


def cmd(args, timeout=300, cwd=ROOT, env=None):
    return subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=timeout, env=env)


def log_step(report, name, args, timeout=300, env=None):
    try:
        result = cmd(args, timeout, env=env)
        text = result.stdout
        returncode = result.returncode
    except subprocess.TimeoutExpired as exc:
        # On a hanging GDScript test, preserve partial Godot errors for diagnosis.
        text = exc.stdout or b''
        if isinstance(text, bytes):
            text = text.decode('utf-8', errors='replace')
        text += f'\nTIMEOUT after {timeout} seconds\n'
        returncode = 124
    log_path = BUILD / f'qa-{name}.log'
    log_path.write_text(text, encoding='utf-8')
    error_lines = [line for line in text.splitlines() if
                   line.startswith(('ERROR:', 'SCRIPT ERROR:', 'Parse Error:', 'TIMEOUT'))]
    success = returncode == 0 and not error_lines
    report['steps'][name] = {'passed': success, 'returncode': returncode,
                             'errors': error_lines[:20], 'log': str(log_path.relative_to(ROOT))}
    print(f'{name}: {"PASS" if success else "FAIL"} — {log_path}')
    if not success:
        print('\n'.join(text.splitlines()[-100:]), file=sys.stderr)
    return success, text


def find_godot(requested):
    candidates = [requested, os.environ.get('GODOT_BIN'),
                  str(ENGINE_DIR / 'Godot_v4.7.2-stable_linux.x86_64'),
                  shutil.which('godot'), shutil.which('godot4')]
    for item in candidates:
        if item and Path(item).is_file() and os.access(item, os.X_OK):
            return str(Path(item).resolve())
    return None


def install_godot():
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        raise RuntimeError('Automatic installation supports Linux x86_64 only; supply --godot')
    ENGINE_DIR.mkdir(exist_ok=True)
    if not ENGINE_ARCHIVE.exists():
        try:
            with urllib.request.urlopen(DOWNLOAD_URL, timeout=25) as remote, ENGINE_ARCHIVE.open('wb') as dst:
                shutil.copyfileobj(remote, dst)
        except Exception as exc:
            ENGINE_ARCHIVE.unlink(missing_ok=True)
            raise RuntimeError(f'Unable to fetch pinned official editor: {exc}') from exc
    actual = hashlib.sha256(ENGINE_ARCHIVE.read_bytes()).hexdigest()
    if actual != EXPECTED_SHA256:
        ENGINE_ARCHIVE.unlink(missing_ok=True)
        raise RuntimeError(f'Official archive integrity FAILED. Got SHA256 {actual}')
    with zipfile.ZipFile(ENGINE_ARCHIVE) as archive:
        names = archive.namelist()
        allowed = ['Godot_v4.7.2-stable_linux.x86_64']
        if names != allowed:
            raise RuntimeError('Unexpected Godot archive contents; refusing extraction')
        archive.extract(names[0], ENGINE_DIR)
    executable = ENGINE_DIR / allowed[0]
    executable.chmod(0o755)
    return str(executable)


def write(report):
    BUILD.mkdir(exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['doctor', 'check', 'render'])
    p.add_argument('--godot')
    p.add_argument('--install', action='store_true', help='Fetch official SHA256-pinned Linux editor when allowed')
    args = p.parse_args()
    BUILD.mkdir(exist_ok=True)
    report = {'pin': VERSION, 'os': platform.platform(), 'python': sys.version.split()[0],
              'source': os.environ.get('GITHUB_SHA', 'local-unverified-working-tree'), 'engine_installed': False,
              'engine_tested': False, 'render_tested': False, 'steps': {}}
    engine = find_godot(args.godot)
    if engine is None and args.install:
        try:
            engine = install_godot()
        except RuntimeError as exc:
            report['engine_unavailable_reason'] = str(exc)
    report['engine_path'] = engine
    report['xvfb_run_available'] = bool(shutil.which('xvfb-run'))
    if not engine:
        report.setdefault('engine_unavailable_reason', 'No pinned Godot editor found; pass --godot or --install')
        print('GODOT NOT AVAILABLE:', report['engine_unavailable_reason'])
        write(report)
        return 0 if args.action == 'doctor' else 2
    check, vtext = log_step(report, 'engine-version', [engine, '--version'])
    actual = vtext.strip()
    good_version = check and (actual == VERSION or actual.startswith(VERSION + '.'))
    report['engine_installed'] = good_version
    report['actual_engine_version'] = actual
    if not good_version:
        print(f'Expected pinned Godot {VERSION}, got {actual}', file=sys.stderr)
        write(report)
        return 3
    if args.action == 'doctor':
        print(f'Pinned Godot verified: {actual}')
        write(report)
        return 0
    if args.action == 'check':
        ok, _ = log_step(report, 'python-complete-regression', [sys.executable, '-m',
            'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py', '-q'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'acceptance-static-preflight', [sys.executable,
            'tools/production_acceptance.py', 'prepare'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-contracts', [sys.executable, 'tools/check_step06.py'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-step18-20', [sys.executable, '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_step18_20.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-audit-repairs', [sys.executable, '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_audit_repairs.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-step21-materials', [sys.executable, '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_step21_materials.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-step25-blockout', [sys.executable, '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_step25_blockout.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-step26-30-districts', [sys.executable, '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_step26_30_districts.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-brinewick-integrated', [sys.executable, '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_brinewick_integration.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-reference-architecture', [sys.executable, '-m', 'unittest',
            'discover', '-s', 'tests', '-p', 'test_reference_buildings.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-step44-audit-failure-modes',
            [sys.executable, '-m', 'unittest', 'discover', '-s', 'tests',
             '-p', 'test_step44_audit.py', '-v'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'python-step44-data-audit',
            [sys.executable, 'tools/audit_step44.py'])
        if not ok:
            write(report)
            return 1
        ok, _ = log_step(report, 'godot-import', [engine, '--headless', '--path', str(ROOT/'game'), '--editor', '--quit'], 180)
        if not ok:
            write(report)
            return 1
        suites = [
            ('godot-smoke', [engine, '--headless', '--path', str(ROOT/'game'), '--', '--smoke-test'], 'HOLLOWMERE_SMOKE_OK'),
            *[(f'godot-step{i}', [engine, '--headless', '--path', str(ROOT/'game'), '--script',f'res://tests/test_step{i}.gd'],
               'HOLLOWMERE_STEP06_TEST_OK' if i == '06' else f'HOLLOWMERE_STEP{i}_TESTS_OK') for i in ['04','05','06']],
            ('godot-physics', [engine, '--headless', '--path', str(ROOT/'game'), '--script', 'res://tests/test_step06_physics.gd'],
             'HOLLOWMERE_STEP06_PHYSICS_OK'),
            ('godot-step07', [engine, '--headless', '--path', str(ROOT/'game'), '--script', 'res://tests/test_step07.gd'],
             'HOLLOWMERE_STEP07_TEST_OK'),
            ('godot-step08', [engine, '--headless', '--path', str(ROOT/'game'), '--script', 'res://tests/test_step08.gd'],
             'HOLLOWMERE_STEP08_TEST_OK'),
            ('godot-step09', [engine, '--headless', '--path', str(ROOT/'game'), '--script', 'res://tests/test_step09.gd'],
             'HOLLOWMERE_STEP09_TEST_OK'),
            ('godot-step10', [engine, '--headless', '--path', str(ROOT/'game'), '--script', 'res://tests/test_step10.gd'],
             'HOLLOWMERE_STEP10_TEST_OK'),
            ('godot-step11', [engine, '--headless', '--path', str(ROOT/'game'), '--script', 'res://tests/test_step11.gd'],
             'HOLLOWMERE_STEP11_TEST_OK'),
            ('godot-step12', [engine, '--headless', '--path', str(ROOT/'game'), '--script', 'res://tests/test_step12.gd'],
             'HOLLOWMERE_STEP12_TEST_OK'),
            ('godot-step17-integration', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
             'res://tests/test_step17_integration.gd'], 'HOLLOWMERE_STEP17_INTEGRATION_OK'),
            *[(f'godot-step{i}', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
                f'res://tests/test_step{i}.gd'], f'HOLLOWMERE_STEP{i}_TEST_OK')
              for i in ('13','14','15','16','17','18','19','20')],
            ('godot-audit-repairs', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
                'res://tests/test_audit_repairs.gd'], 'HOLLOWMERE_AUDIT_REPAIRS_OK'),
            ('godot-step21', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
                'res://tests/test_step21.gd'], 'HOLLOWMERE_STEP21_TEST_OK'),
            *[(f'godot-step{i}', [engine, '--headless', '--path', str(ROOT/'game'),
                '--script', f'res://tests/test_step{i}.gd'], f'HOLLOWMERE_STEP{i}_TEST_OK')
              for i in ('22','23','24','25','26','27','28','29','30')]]
        suites.append(('godot-brinewick-integration', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_brinewick_integration.gd'], 'HOLLOWMERE_BRINEWICK_INTEGRATION_OK'))
        suites.append(('godot-brinewick-smoke', [engine, '--headless', '--path', str(ROOT/'game'), '--',
            '--brinewick-smoke-test'], 'HOLLOWMERE_BRINEWICK_SMOKE_OK'))
        suites.append(('godot-brinewick-priorities', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_brinewick_priorities.gd'], 'HOLLOWMERE_BRINEWICK_PRIORITIES_OK'))
        suites.append(('godot-brinewick-migration', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_brinewick_save_migration.gd'], 'HOLLOWMERE_BRINEWICK_MIGRATION_OK'))
        suites.append(('godot-act-iii-material-migration', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_requisition_family_migration.gd'], 'HOLLOWMERE_ACT_III_MATERIAL_MIGRATION_OK'))
        suites.append(('godot-brinewick-real-ray', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_brinewick_real_ray.gd'], 'HOLLOWMERE_BRINEWICK_REAL_RAY_OK'))
        suites.append(('godot-reference-architecture', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_reference_buildings.gd'], 'HOLLOWMERE_REFERENCE_ARCHITECTURE_OK'))
        suites.append(('godot-reference-access', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_reference_access.gd'], 'HOLLOWMERE_REFERENCE_ACCESS_OK'))
        suites.append(('godot-phase-e-f', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_e_f.gd'], 'HOLLOWMERE_PHASE_E_F_TEST_OK'))
        suites.append(('godot-phase-e-f-physics-path', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_e_f_path.gd'], 'HOLLOWMERE_PHASE_E_F_PATH_OK'))
        suites.append(('godot-campaign-four-acts', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_campaign_four_acts.gd'], 'HOLLOWMERE_FOUR_ACTS_TRANSACTION_OK'))
        suites.append(('godot-physical-first-person', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_ef_first_person.gd'], 'HOLLOWMERE_FIRST_PERSON_TARGET_QA_OK'))
        suites.append(('godot-phase-e-f-player-motion', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_ef_player_motion.gd'], 'HOLLOWMERE_PLAYER_ROUTE_MOTION_OK'))
        suites.append(('godot-visual-rebuild-phase1', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_visual_rebuild_phase1.gd'], 'HOLLOWMERE_VISUAL_REBUILD_PHASE1_OK'))
        suites.append(('godot-visual-cart-route', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_visual_rebuild_cart_road.gd'], 'HOLLOWMERE_VISUAL_CART_ROUTE_OK'))
        suites.append(('godot-visual-batch03', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_visual_rebuild_batch03.gd'], 'HOLLOWMERE_VISUAL_BATCH03_OK'))
        suites.append(('godot-production-world-art', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_production_world_art.gd'], 'HOLLOWMERE_PRODUCTION_WORLD_ART_OK'))
        suites.append(('godot-phase-b-visual-contract', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_b_visual.gd'], 'HOLLOWMERE_PHASE_B_VISUAL_OK'))
        suites.append(('godot-phase-c-visual-contract', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_c_visual.gd'], 'HOLLOWMERE_PHASE_C_VISUAL_OK'))
        suites.append(('godot-phase-g', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_g.gd'], 'HOLLOWMERE_PHASE_G_TEST_OK'))
        suites.append(('godot-landmark-components', [engine, '--headless', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_landmark_components.gd'], 'HOLLOWMERE_LANDMARK_COMPONENTS_OK'))
        suites.append(('godot-step44-progression-economy', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_step44.gd'],
            'HOLLOWMERE_STEP44_TEST_OK'))
        suites.append(('godot-step45-save-recovery', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_step45_save_recovery.gd'],
            'HOLLOWMERE_STEP45_RECOVERY_OK'))
        suites.append(('godot-g1-harbour-physics', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_g1_harbour_route.gd'],
            'HOLLOWMERE_G1_HARBOUR_ROUTE_OK'))
        suites.append(('godot-g2-cottage-assets', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_g2_cottage_assets.gd'],
            'HOLLOWMERE_G2_COTTAGE_ASSET_OK'))
        suites.append(('godot-g2-hero-part-ownership', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_g2_hero_architecture.gd'],
            'HOLLOWMERE_G2_HERO_OWNERSHIP_OK'))
        suites.append(('godot-g3-district-ownership', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_g3_district_pilot.gd'],
            'HOLLOWMERE_G3_DISTRICT_PILOT_OK'))
        suites.append(('godot-g3-roof-inward-pitch', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_g3_roof_geometry.gd'],
            'HOLLOWMERE_G3_ROOFS_CORRECT_OK'))
        suites.append(('godot-g4-protected-architecture', [engine, '--headless', '--path',
            str(ROOT/'game'), '--script', 'res://tests/test_g4_protected_composition.gd'],
            'HOLLOWMERE_G4_PROTECTED_COMPOSITION_OK'))
        for name, command, marker in suites:
            ok, output = log_step(report, name, command, 60)
            if not ok or marker not in output:
                if ok:
                    report['steps'][name]['passed'] = False
                    report['steps'][name]['errors'].append('Required success marker missing')
                write(report)
                return 1
        report['engine_tested'] = True
        write(report)
        print('PINNED GODOT ENGINE SUITES ALL PASSED')
        return 0
    if args.action == 'render':
        if not shutil.which('xvfb-run'):
            print('Xvfb unavailable, cannot execute actual visual rendering', file=sys.stderr)
            write(report)
            return 2
        capture = BUILD / 'step06-engine-frame.png'
        env = os.environ.copy()
        env['HOLLOWMERE_SCREENSHOT'] = str(capture)
        env['LIBGL_ALWAYS_SOFTWARE'] = '1'
        env['GODOT_HEADLESS'] = 'false'
        # The cloud runner has no sound card. Disable only audio for this
        # rendered-frame test; keep the real Vulkan/Forward+ renderer enabled.
        command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', engine,
                   '--audio-driver', 'Dummy', '--path', str(ROOT/'game'),
                   '--script', 'res://tests/test_step06_capture.gd']
        ok, output = log_step(report, 'godot-render', command, 180, env)
        report['render_tested'] = ok and 'HOLLOWMERE_STEP06_RENDER_OK' in output and capture.is_file()
        if report['render_tested']:
            report['screenshot_sha256'] = hashlib.sha256(capture.read_bytes()).hexdigest()
        if not report['render_tested']:
            write(report)
            return 1
        env['HOLLOWMERE_MATERIAL_RENDER_DIR'] = str(BUILD.resolve())
        material_render = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', engine,
            '--audio-driver', 'Dummy', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_step21_capture.gd']
        ok, material_output = log_step(report, 'godot-step21-material-render', material_render, 180, env)
        frames = [BUILD / ('step21-materials-' + mode + '.png') for mode in ('neutral', 'coastal')]
        report['step21_render_tested'] = ok and 'HOLLOWMERE_STEP21_RENDER_OK' in material_output and all(f.is_file() and f.stat().st_size > 10000 for f in frames)
        if report['step21_render_tested']:
            report['step21_screenshot_sha256'] = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in frames}
        if not report['step21_render_tested']:
            write(report)
            return 1
        env['HOLLOWMERE_BLOCKOUT_RENDER_DIR'] = str(BUILD.resolve())
        level_render = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', engine,
            '--audio-driver', 'Dummy', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_step25_capture.gd']
        ok, level_output = log_step(report, 'godot-step25-blockout-render', level_render, 180, env)
        level_frames = [BUILD / ('step25-brinewick-' + mode + '.png') for mode in ('aerial','harbour')]
        report['step25_render_tested'] = ok and 'HOLLOWMERE_STEP25_RENDER_OK' in level_output and all(f.is_file() and f.stat().st_size > 10000 for f in level_frames)
        if report['step25_render_tested']:
            report['step25_screenshot_sha256'] = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in level_frames}
        if not report['step25_render_tested']:
            write(report)
            return 1
        env['HOLLOWMERE_REFERENCE_RENDER_DIR'] = str(BUILD.resolve())
        reference_render = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', engine,
            '--audio-driver', 'Dummy', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_reference_capture.gd']
        ok, output = log_step(report, 'godot-production-reference-render', reference_render, 180, env)
        refs = [BUILD / ('reference-' + mode + '.png') for mode in ('cottage','warehouse')]
        report['reference_render_tested'] = ok and 'HOLLOWMERE_REFERENCE_RENDER_OK' in output and all(
            f.is_file() and f.stat().st_size > 10000 for f in refs)
        if report['reference_render_tested']:
            report['reference_screenshot_sha256'] = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in refs}
        if not report['reference_render_tested']:
            write(report)
            return 1
        env['HOLLOWMERE_UNDERGROUND_RENDER_DIR'] = str(BUILD.resolve())
        underground_command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24', engine,
            '--audio-driver', 'Dummy', '--path', str(ROOT/'game'), '--script',
            'res://tests/test_phase_e_capture.gd']
        ok, output = log_step(report, 'godot-phase-e-render', underground_command, 180, env)
        underground_frames = [BUILD / ('phase-e-' + name + '.png') for name in ('well','mine','undercroft','bell','harbour','headland','inn','mine_office','chapel','shore')]
        report['phase_e_render_tested'] = ok and 'HOLLOWMERE_PHASE_E_RENDER_OK' in output and all(
            f.is_file() and f.stat().st_size > 10000 for f in underground_frames)
        if report['phase_e_render_tested']:
            report['phase_e_frame_sha256'] = {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in underground_frames}
        if report['phase_e_render_tested']:
            ok, _ = log_step(report, 'production-capture-file-audit', [sys.executable,
                'tools/production_acceptance.py', 'review', '--frames-dir', str(BUILD)])
            report['production_capture_files_audited'] = ok
            if not ok:
                write(report)
                return 1
        if report['phase_e_render_tested']:
            env['HOLLOWMERE_G1_CAPTURE_DIR'] = str(BUILD.resolve())
            g1_command = ['xvfb-run', '-a', '-s', '-screen 0 1280x720x24',
                engine, '--audio-driver', 'Dummy', '--path', str(ROOT/'game'),
                '--script', 'res://tests/test_g1_harbour_capture.gd']
            ok, g1_output = log_step(report, 'godot-g1-fixed-camera', g1_command, 180, env)
            g1_views = ('01_quay_eye','02_warehouse_eye','03_cottage_eye',
                '04_embankment_eye','05_coastal_wide')
            g1_frames = [BUILD / ('g1-' + name + '.png') for name in g1_views]
            report['g1_render_tested'] = (ok and 'HOLLOWMERE_G1_CAPTURE_OK' in g1_output
                and all(f.is_file() and f.stat().st_size > 10000 for f in g1_frames))
            if report['g1_render_tested']:
                report['g1_frame_sha256'] = {
                    f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in g1_frames}
            if not report['g1_render_tested']:
                write(report)
                return 1
        write(report)
        return 0 if report['phase_e_render_tested'] and report.get('g1_render_tested') else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, subprocess.TimeoutExpired, zipfile.BadZipFile, ValueError) as exc:
        print(f'QA environment failed: {exc}', file=sys.stderr)
        sys.exit(1)