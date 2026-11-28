# Agent / CI process notes

Cloud agents use `.cursor/environment.json` (`tool/ci/install_flutter_pinned.sh`).
Run `flutter analyze lib test --no-fatal-infos` and targeted tests locally before push.
Full `flutter test --exclude-tags sim` runs on GitHub CI only.