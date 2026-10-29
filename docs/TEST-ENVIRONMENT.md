# Hollowmere — pinned Godot 4.7.2 test environment (Step06 QA)

This is an executable test harness packaged with the actual game source, not a simulation of Godot. It will **not** claim success from Python tests when the engine cannot be executed.

## Status and execution environments

- Tested locally in the current restricted Linux container: Step04–06 Python tests and harness logic. Godot binary cannot be downloaded from official hosts in this container. Thus Godot tests, rendered screenshots and Windows runtime remain **UNTESTED** here.
- The GitHub Actions workflow `.github/workflows/hollowmere-engine-tests.yml` is **prepared, not connected or executed**. It becomes active if this same source is pushed into a GitHub repository with Actions enabled. Do not create/modify unrelated repos for QA.
- Official binary pins: Godot Standard 4.7.2 Linux x86_64 GitHub release asset, sha256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`, obtained from official GitHub release asset metadata on 27 October 2026. Downloading uses HTTPS and checks the exact SHA256 **before** executing binary. Windows native Godot Standard 4.7.2 win64.exe.zip asset SHA256 is `731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953`. Exact release version output is rechecked.
- This setup does not need the user's PC. A Linux CI runner can run the engine and software-render tests in the cloud, and a separate Windows CI runner can run Godot and persistence tests natively in headless mode, after GitHub repository/CI connection is established.

## Commands

```sh
python tools/test_environment.py doctor
python tools/test_environment.py check --install
python tools/test_environment.py check --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
python tools/test_environment.py render --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
```

The tool records `build/qa-environment.json` plus individual step logs, exits nonzero if the engine is unavailable for `check`/`render`, and detects failed Godot tests by both process return code and required success markers. `doctor` is allowed to report missing editor without failing; don't confuse that with successful testing.

**Godot tests**: import project, Step03 menu/stage/menu smoke, Step04 catalogs/economy, Step05 real save roundtrip/corruption fallback, Step06 controller API and actual physics walking/jumping/collisions/pause. **Visual test**: Xvfb software-rendered Godot frame exported as PNG and saved as a CI artifact.

Limits: screenshot capture is evidence of a frame, not a human assessment of appearance or play feel. Headless Linux and software Vulkan rendering do not replace native Windows graphical input/audio tests. Large export templates and Windows executable testing are separate later milestones.

## Secure handling and archival

`.qa-tools/`, `.godot/` and `build/` are generated locally, never committed. Preserve Step03–06 original ZIPs. The QA source archive is `Hollowmere-Source-Step06-QA01.zip`, preserving Git history, test scripts and CI config. Do not bundle the 77 MB engine in game source. Keep Godot and its required licence notices separate from game content.
