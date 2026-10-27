# Xerno Music

Editorial music player for the Xernover library. It runs on Linux desktops, including CachyOS, and on Android.

The interface is a matte obsidian and forest-green layout with Newsreader headlines, Outfit text, and tabular track numbers. Frosted glass on the now playing bar and sheets can be turned off in Settings for a pure matte surface.

## What it plays

The app ships with `assets/library.json`, the master catalog: `liked_1_80`, `illit_osszes`, `ocsem_random`, and `kanye_west_bangers`, plus every track record in that file. Settings opens with the RöcsögeCloud manifest at `https://cloud.mucsarocsoge.online/u/6fffca60-36cb-447b-b71a-6d823ccaa0bc.json`, so Refresh manifest works without typing a URL. That field also accepts any other manifest URL, or the app can read `library.json` from an unzipped `spotify_library` folder on disk.

A track plays from, in order:

- a pinned 320 kbps MP3 in app storage
- `file.relative_path` inside the local library folder
- `file.zipline_url`, or the audio base URL joined with that relative path

Cloud first reverses the remote and local preference. Pins are still used when they are the only copy on hand. YouTube URLs in the catalog are metadata and are not fetched.

Search, artist, and album views sit next to the four premade playlists. Lists sort by position, title, artist, album, year, duration, or popularity.

## Playlists, favorites, and offline pins

Hearts and custom playlists stay on the device. They can be reordered, renamed, exported, and imported as `xerno.user_library.v1` JSON. Merge adds incoming tracks. Replace writes the file over this device's favorites and playlists.

Pin a track, or a whole playlist, to download the MP3 into the app's offline folder. If the catalog has no cloud URL yet, pinning copies the local file instead.

## Playback

- Linux uses libmpv through `just_audio` and publishes an MPRIS interface (`org.mpris.MediaPlayer2.xernomusic`) so media keys and desktop applets can control it. If `mpv` is not installed the window still opens and shows `sudo pacman -S mpv`. The release build draws with Skia so the window maps on Wayland. `XERNO_ENABLE_IMPELLER=1` turns Impeller back on.
- Android keeps a foreground media notification and lock-screen controls.
- The Linux mini-player toggle asks the window to stay above other windows and shrink to a compact size.
- Lyrics are requested from [LRCLIB](https://lrclib.net/api/get) and fall back to a plain text version. Synced lines follow the playhead.
- Crossfade runs from 0 to 12 seconds. Speed and pitch apply on both platforms. The five-band equalizer is applied by Android's audio effect; on Linux the bands are stored with the rest of the settings.
- Sleep can be 15, 30, 45, or 60 minutes, or the end of the current track.

## Device sync

Settings has two ways to share favorites, custom playlists, and the playback bookmark.

**Quick device sync** uses a room code. No email. Point the app at a Supabase project (URL plus anon key) or at a REST base that accepts `PUT` and `GET` on `{base}/sync/{code}`. The Supabase table is `sync_rooms`. Live sync subscribes to changes and applies a remote copy when its timestamp is newer. A manual pull always takes the remote copy, including while something is playing.

**Account sync** is optional email and password, or a magic link, through `supabase_flutter`. Libraries live in `user_libraries` and follow the signed-in user over Postgres changes. The audio base URL can be a Supabase Storage or R2/S3 prefix.

Paste [`supabase/schema.sql`](supabase/schema.sql) into the Supabase SQL Editor and run it once. It creates both tables, row level security, realtime publication, and a public `xerno-audio` bucket when storage is available. Room rows are readable with the anon key, so treat the room code as the secret and keep the project private.

## Develop

Flutter 3.47 or newer, with the Linux desktop target enabled:

```bash
sudo pacman -S --needed gtk3 libmpv mpv libsecret zenity clang cmake ninja pkgconf
flutter pub get
flutter run -d linux
```

`zenity` (or `kdialog`) is what the folder and playlist file dialogs use.

```bash
flutter analyze
flutter test
flutter build linux --release
```

The release bundle is `build/linux/x64/release/bundle`.

## Install on CachyOS / Arch

From a GitHub release archive:

```bash
packaging/arch/install-release.sh XernoMusic-1.0.0-linux-x86_64.tar.gz
```

That copies the bundle to `/opt/xerno-music`, links `/usr/bin/xerno-music`, and installs the desktop entry. Runtime packages are `gtk3`, `libmpv`, `mpv`, `libsecret`, and `zenity`. The bundle also carries the libmpv build used by media_kit.

To build a package from this checkout, with Flutter on `PATH`:

```bash
cd packaging/arch && makepkg -si
```

An AppImage can be produced from the release bundle with `packaging/linux/make_appimage.sh`.

## Android

```bash
flutter build apk --release --split-per-abi
flutter build apk --release
```

Release builds sign with the debug keystore unless `XERNO_KEYSTORE_PATH`, `XERNO_KEYSTORE_PASSWORD`, `XERNO_KEY_ALIAS`, and `XERNO_KEY_PASSWORD` are set. The app id is `online.mucsarocsoge.xerno_music`. Cleartext HTTP is allowed so a LAN manifest or audio URL can be used.

## Releases

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) analyzes, tests, and builds the Linux bundle and Android APKs on pushes, pull requests, and manual runs.

[`.github/workflows/release.yml`](.github/workflows/release.yml) runs on `v*` tags and on manual dispatch. It uploads the Linux `.tar.gz` and `.AppImage` (when AppImage tooling succeeds) and the universal plus per-ABI APKs to a GitHub Release.
