# Dear Diary — mobile prototype

This repository contains a Flutter prototype for Android and iOS. The diary and PINs are local and unencrypted. The hidden conversation flow includes Supabase email/password accounts, a development-only username/password mode, and the first online text-chat implementation. It still needs the project's SQL migration and Realtime publication configured before two accounts can communicate. Message and diary text are not end-to-end encrypted. Use sample content only.

## Try the prototype

- Enter `000000` for the diary or `111111` for the conversation area.
- In the diary, tap the title six times within three seconds to open PIN settings. Changing either PIN requires its current PIN. To open the conversation from that dialog, select Conversation PIN, enter its current PIN, and tap Open.
- The online chat supports username friend requests, accept/decline, one 1:1 chat per pair, text messages, server timestamps, read receipts and instant lock. Media and chat search/export are not connected to this cloud flow yet.
- Configure a separate Supabase development project as described in [SUPABASE_DEV_SETUP.md](SUPABASE_DEV_SETUP.md), then create accounts on two devices. Sign out is inside the hidden PIN settings.
- Backgrounding the app returns it to the PIN screen. This is a prototype lifecycle implementation, not a verified security boundary.

## Status checklist

- [x] Flutter Android/iOS project, PIN routing and local PIN settings
- [x] Diary notes, local autosave, latest-entry view
- [x] Supabase text chat, friend requests, sent/read receipts, realtime subscriptions
- [ ] Encrypted local storage and hardware-backed key protection
- [x] Email/password account gate, development-only username/password mode, and hidden-settings sign out
- [x] Initial Supabase SQL schema and row-level access policies
- [ ] Apply migration to a development project, enable Realtime, and verify two accounts across devices
- [ ] End-to-end encryption and independent security review
- [ ] Reliable real-device delivery/background synchronization
- [ ] Sending/receiving encrypted audio, photos, video and stickers
- [ ] Live location, permissions and stop controls
- [ ] Notifications, content-free push service, device recovery
- [ ] Chat snapshots and encrypted export/import; diary sharing/export
- [ ] Theme selection, production icons and accessibility review
- [ ] Real-device Android and iOS security and reliability review
- [ ] Signed iOS build, Apple developer account and TestFlight setup

See [SUPABASE_DEV_SETUP.md](SUPABASE_DEV_SETUP.md) for the current development account setup, and [BACKEND_SETUP.md](BACKEND_SETUP.md) for longer-term encrypted messaging and iPhone setup requirements.

## Release builds

Push a version tag such as `v1.0.0-demo` to run `.github/workflows/release.yml`. The workflow builds split-per-ABI Android APKs and an **unsigned iOS IPA**, then attaches both to a GitHub pre-release.

Android testers can download the APK matching their device from the repository's **Releases** page, then allow installation from that source when Android prompts. These prototype builds use the Android debug signing key and are for testing only.

The iOS IPA is **not directly installable**. For personal testing from Windows, a sideloading tool such as [AltServer/AltStore](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) can sign it using your Apple Account; free signatures expire after seven days and must be refreshed. For TestFlight distribution, an Apple Developer Program membership is required. This repo does not contain Apple signing credentials.

Do not upload real diary entries or sensitive messages. Chat text is stored in Supabase plaintext and diary/PIN data is local and unencrypted. Use a disposable development project and sample data until encryption and recovery are implemented and reviewed.

