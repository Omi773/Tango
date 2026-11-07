# Tango

A local-files music player for iPhone, built with Flutter and Material 3. Tango plays the music you own, from your device or from network storage, with an interface modelled on the Android player [Rhythm](https://github.com/cromaguy/Rhythm).

## Features

- Play local audio files and folders, with a library of tracks, albums, artists and playlists
- Queue, search, and a full-screen player with synced lyrics
- Equalizer, listening statistics and a listening rewind
- Network storage (SMB) for music kept on a server or NAS
- Backup and restore of your library data and settings
- Optional Discord activity, off until you connect it
- Dynamic colour and Rhythm's expressive shapes, sheets, dialogs and motion

## Install

Tango is built by the **Build iOS (Signed IPA)** GitHub Actions workflow (Actions tab → run the workflow manually). Download the resulting `.ipa` and install it on your iPhone with a sideloading tool such as Feather, AltStore or Sideloadly.

## Build from source

You need Flutter 3.47.7 (the version pinned in `.fvmrc`), Xcode on macOS and a Rust toolchain for the backend in `rust_backend/`. The Discord SDK framework is fetched from the repository's `discord-sdk` release, as the workflow does.

```sh
flutter pub get
flutter gen-l10n
flutter run
```

`scripts/build_rust_backend.sh`, `scripts/build_ios.sh` and `.github/workflows/ios.yml` show how the iOS build is produced.

## Privacy

Tango has no servers, analytics, advertising or tracking. Read the [Privacy Policy](docs/PRIVACY.md) and [Terms of Service](docs/TERMS.md).

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Changes are recorded in [CHANGELOG.md](CHANGELOG.md).

## Licence and credits

Tango is released under the [MIT License](LICENSE). Its interface is based on Rhythm by Anjishnu Nandi, which is licensed GPL-3.0-or-later, and it uses many other open-source packages. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
