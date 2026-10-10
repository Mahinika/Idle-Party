# A56 reference (Idle Party)

Read when the AVD is missing, stutters, or has the wrong RAM.

## Recreate the AVD (only if missing)

```bash
avdmanager create avd -n Samsung_A56 -k "system-images;android-36;google_apis;x86_64" -d pixel_6 --force
```

Then set in `$env:USERPROFILE/.android/avd/Samsung_A56.avd/config.ini`:

- `hw.lcd.width=1080` · `hw.lcd.height=2340` · `hw.lcd.density=480`
- `hw.device.manufacturer=Samsung` · `hw.device.name=Galaxy A56`
- `showDeviceFrame=no` · `skin.name=1080x2340`
- `hw.ramSize=6144` · `vm.heapSize=512M` · `hw.cpu.ncore=4` · `hw.gpu.mode=host`

Google does not ship One UI. **Screen size** is what we need.
**2G RAM on this Android 16 image fills swap** and the window stutters
even on a quiet hub. Keep 6G. After a RAM change, cold-boot once
(`emulator -avd Samsung_A56 -no-snapshot-load`) so the old snapshot
does not boot the 2G size again.
