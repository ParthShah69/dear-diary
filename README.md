# Dear Diary — mobile prototype

This repository contains a local UI prototype for Android and iOS. It is not a secure messaging app: diary notes, messages, and configurable demo PINs are stored unencrypted on the device. Use sample content only.

## Try the prototype

- Enter `000000` for the diary or `111111` for the local conversation preview.
- In the diary, tap the title six times within three seconds to open PIN settings. Changing either PIN requires its current PIN. To open the conversation from that dialog, select Conversation PIN, enter its current PIN, and tap Open.
- The conversation preview has locally stored draft text, message editing/history, search, and an Instant Lock button that returns to the most recently opened diary entry. It does not send messages to another user.
- Backgrounding the app returns it to the PIN screen. This is a prototype lifecycle implementation, not a verified security boundary.

## Status checklist

- [x] Flutter Android/iOS project, PIN routing and local PIN settings
- [x] Diary notes, local autosave, latest-entry view
- [x] Local chat preview, drafts, edit history, text/date search, instant return
- [ ] Encrypted local storage and hardware-backed key protection
- [ ] Secure account system, friend requests and two-person pairing
- [ ] Real-time server and independently verified end-to-end encryption
- [ ] Read receipts, message delivery and real-time synchronization
- [ ] Sending/receiving encrypted audio, photos, video and stickers
- [ ] Live location, permissions and stop controls
- [ ] Notifications, content-free push service, device recovery
- [ ] Chat snapshots and encrypted export/import; diary sharing/export
- [ ] Theme selection, production icons and accessibility review
- [ ] Real-device Android and iOS security and reliability review
- [ ] Signed iOS build, Apple developer account and TestFlight setup

See [BACKEND_SETUP.md](BACKEND_SETUP.md) for the server and iPhone setup requirements.

## Release builds

Push a version tag such as `v1.0.0-demo` to run `.github/workflows/release.yml`. The workflow builds split-per-ABI Android APKs and attaches them to a GitHub Release. The macOS job also builds an **unsigned** iOS app archive as a workflow artifact.

Android testers can download the APK matching their device from the repository's **Releases** page, then allow installation from that source when Android prompts. These prototype builds use the Android debug signing key and are for testing only.

The iOS archive is **not installable on an iPhone**. Installing on a physical iPhone requires signing with an Apple Developer team and a provisioning profile (or distributing through TestFlight). This repo does not contain Apple signing credentials. Build and signing details are in [BACKEND_SETUP.md](BACKEND_SETUP.md).

Do not upload real diary entries, messages, photos, audio, or location data. There is no production encryption, account system, or remote chat service in this prototype.

