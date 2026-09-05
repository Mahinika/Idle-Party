Drop the approved RepoClip MP4 here as `boot_intro.mp4` (9:16, no watermark).

Then add `- assets/video/boot_intro.mp4` under `flutter.assets` in `pubspec.yaml`
and set `CustomAssets.introVideoBundled` to `true`. Until that file exists the
painted 3-beat intro plays.
