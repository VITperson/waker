# Waker

Minimal macOS menu bar utility that rotates focus between the windows you select.

## What it does

- shows a menu bar icon
- lists regular app windows detected through the macOS Accessibility API
- lets you choose which windows should participate in the loop
- switches focus between selected windows every `N` seconds
- can also jiggle the mouse every `N` seconds to better reset idle state

## Run locally

```bash
swift run
```

You can also open `Package.swift` in Xcode and run the executable target there.

## Build a DMG

```bash
bash ./scripts/build_dmg.sh
```

This creates:

- `dist/Waker.app`
- `dist/Waker.dmg`
- `dist/Waker-icon.png`

The build script clears local Swift build caches first, so it is safe to run after copying the project to a different Mac.

## Share the source project

If you want another Mac to build the app locally, create a clean source archive that excludes machine-specific caches:

```bash
bash ./scripts/make_source_bundle.sh
```

This creates:

- `dist/Waker-source.zip`

Send `Waker-source.zip`, not the whole folder with `.build`.

## Build on another Mac

1. Unzip `Waker-source.zip`.
2. Open Terminal in the extracted `waker` folder.
3. Run:

```bash
bash ./scripts/build_dmg.sh
```

If you want to run from source instead of creating the app bundle:

```bash
rm -rf .build dist
swift run
```

## First launch

1. Start the app.
2. Click the `Waker` icon in the menu bar.
3. Press `Request Access` and allow the app in `System Settings > Privacy & Security > Accessibility`.
4. Optionally leave `Simulate mouse movement` enabled and choose its interval.
5. Refresh the window list, select the windows you want, then press `Start`.

If macOS still shows Accessibility as locked after you enabled it:

- click `Refresh Access`
- if that still doesn't help, click `Relaunch Waker`
- when using the packaged build, copy `Waker.app` out of the mounted `.dmg` to a stable folder before granting permissions

## Notes

- Only regular app windows are shown.
- Minimized windows are skipped.
- If a selected window disappears, refresh the list and reselect it.
- Mouse jiggle uses synthetic mouse-move events and may behave differently across apps and macOS versions.
