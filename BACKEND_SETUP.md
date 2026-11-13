# Backend and iPhone setup for Dear Diary

## Current status

The first app build is a local prototype. A Matrix service, accounts, network messaging, encrypted media, delivery/read receipts, friend requests, live location, push notifications, and cross-device history are **not provisioned or verified** by this guide. Do not use the prototype to exchange sensitive information until the encryption and key-management work below is implemented and independently reviewed.

## What you need to provide

1. A hosting choice: a managed Matrix service or a server you administer. A self-hosted server needs a domain, HTTPS certificate, backups, and ongoing security updates. A local server is useful for development but cannot reliably connect two phones outside the local network.
2. Two separate email addresses for the initial accounts. Keep account passwords and recovery keys private; do not put them in source code, screenshots, issue comments, or chat.
3. An email delivery provider and its SMTP details for email verification and password recovery. The exact DNS and sender verification steps depend on the chosen provider.
4. For iPhone builds: access to a Mac with Xcode, or a macOS build service, plus the Apple signing credentials and Apple Developer account needed for your chosen distribution method.
5. A privacy policy and accurate review information before store distribution. Apple and Google require accurate disclosure of app functionality; the reviewer must be able to access and review the protected conversation and settings.

## Recommended backend decision

Use Matrix as the candidate messaging protocol and Synapse as the candidate homeserver. The server handles authentication, encrypted event delivery, device registration, and media storage. PostgreSQL stores server state; Synapse's configured media storage holds uploaded ciphertext. A separately configured object store may be useful at scale, but confirm compatibility and the maintained storage integration before choosing it.

The proposed Flutter Matrix Dart SDK has an AGPL-3.0-only license and requires `flutter_vodozemac` for end-to-end encryption. Confirm license obligations for your planned distribution. Prove that the selected SDK supports current Android and iOS builds, attachment encryption, key recovery, device verification, event caching, edits, receipts, and live-location events before committing to it. If it does not, choose a maintained alternative or supported native bindings. Do not implement a new cryptographic protocol yourself.

## Setup checklist

1. **Choose the provider or host.** Record the homeserver domain, who maintains it, the regions used, backup policy, storage limits, and expected cost. Configure TLS and restrict administrative access. Use a dedicated development environment before creating a production server.
2. **Install Synapse and PostgreSQL using the official deployment guide** or use a reputable managed Matrix provider. Set up persistent storage, protected backups, monitoring, updates, and a documented restore procedure. Avoid copying example secrets into a production configuration.
3. **Configure identity and registration.** Start with invitation-only registration or manually provision two accounts. Verify email ownership, configure SMTP for recovery, use rate limits, and keep administrator credentials outside the app. Confirm the homeserver's email-login and verification configuration with the chosen authentication method.
4. **Build the account and friend-request flow.** Each person has their own account and unique user ID. Search/invite should avoid exposing a public directory by default; the recipient explicitly accepts. Create a private room after acceptance, restrict membership to the intended participants for the initial release, and support blocking/removal and eventual multiple friends.
5. **Initialize E2EE on each device.** Create separate device keys, enable encryption before the first message, verify the other person's device, and require explicit verification for new devices. Use the SDK's supported encrypted key backup and recovery flow. The PIN that opens the app is a local access gate; it is not the Matrix account password or a substitute for E2EE.
6. **Keep sensitive client data protected.** Use encrypted local stores for chat history, drafts, and media; protect keys with Android Keystore and iOS Keychain. Check SDK event and crypto stores as well as app-owned databases and temporary files. Stop or lock access to decrypted chat state on Instant Lock/background, and verify that the SDK actually supports this lifecycle.
7. **Implement encrypted media.** Encrypt image, video, audio, voice-note, and thumbnail bytes before upload. Keys and sensitive metadata travel in encrypted messages. Use private app files for cached media; save to the device gallery only after explicit user action or an enabled preference. Review partial uploads, retries, quotas, and deletion/backup retention.
8. **Add message behavior.** Use transaction IDs for retry-safe sends. Show pending/sent/delivered/read only when the protocol and recipient settings support each state. Keep timestamps, edits, and prior revisions according to a clear retention policy; encryption does not ensure a recipient cannot copy content. Synchronize history to newly verified devices through supported key backup/sharing.
9. **Add consent-based live location.** Confirm SDK/protocol support first. A user starts a bounded session explicitly, sees the recipient and duration, and can stop it. Encrypt updates, retain the minimum needed, and show required OS location indicators. Android and iOS can restrict or delay background updates; display the last update time. Stop sharing by default on Instant Lock.
10. **Configure push notifications.** Set up Android FCM and Apple Push Notification service credentials with the chosen Matrix push gateway. Push payloads should contain no sender, room title, message text, or attachment details. Disabling notifications remains an option. Delivery timing and even generic notification activity may be visible to the operating system and push providers.
11. **Verify across actual devices.** Test the Android app and an iPhone on different networks with two accounts. Cover offline sends/retries, duplicate prevention, app lock during upload/recording, incoming media storage, PIN recovery, device loss, restored key backups, friendship removal, and all location stop conditions. Have an independent security review before trusting the app with sensitive data.

## iPhone testing

An Android APK cannot be installed on an iPhone. From a Mac, open the Flutter iOS project with Xcode, select the signing team and a unique bundle identifier, connect a test iPhone, and build/run. A personal Apple account can run some tests on its own device through Xcode, with Apple's applicable limitations.

For remote testers, enroll in the Apple Developer Program, create the app in App Store Connect, configure signing, build the iOS app on a Mac or macOS build service, and upload it to TestFlight. Add team members as internal testers or create an external tester group; Apple's TestFlight documentation says the first external build needs beta review. Testers install the TestFlight app and accept the invitation. A Windows machine alone cannot produce a signed iOS build with Xcode.

## Sources

- [Synapse installation and email setup](https://element-hq.github.io/synapse/latest/setup/installation.html)
- [Matrix SDK ecosystem and licenses](https://matrix.org/ecosystem/sdks/)
- [Matrix Dart SDK and E2EE dependency](https://github.com/famedly/matrix-dart-sdk)
- [Matrix E2EE and encrypted attachments](https://matrix.org/docs/matrix-concepts/end-to-end-encryption/)
- [Android background location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions)
- [Apple background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
- [Apple developer account and device testing](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [TestFlight distribution](https://developer.apple.com/testflight/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play deceptive behavior policy](https://support.google.com/googleplay/android-developer/answer/17006354)
