# Dear Diary development account setup

This guide configures the username account gate and the first online text-chat flow. The app has exact-username friend requests, accept/decline, one 1:1 conversation per pair, server-backed text messages, sent/read receipt state, and realtime refresh subscriptions. Development project `Dear Diary Dev` (`uxacfkamynlkdpaoguzx`, Mumbai region) is already configured with the migration, Realtime publication, email confirmation off, and the development Auth signup/sign-in limit set to 60 requests per IP per 5 minutes. Production `Dear Diary` is unchanged. Media, push notifications, location, message edits, and end-to-end encryption are not implemented. The SQL stores message/diary text in plaintext at Supabase, so use this disposable development project and test data only.

## What is implemented in the app

- Diary PIN opens the local diary without an account.
- The conversation PIN opens an email/password sign-in or account-creation screen. New accounts choose a separate username for friend lookup.
- Sign out is available only under the six-tap hidden PIN settings while signed in.
- Sign out returns to the diary. Backgrounding/locking the app resets it to the PIN screen; a Supabase session remains signed in until the hidden-settings sign out action.
- Chat uses Supabase after sign-in. Messages are server backed; realtime requires the publication setup below. A build aimed at a project without the migration will show a chat connection/setup error.

The default account flow uses real email/password accounts and a separate username for friend lookup. A development-only username/password mode is available with `--dart-define=USERNAME_ONLY_AUTH=true`. It maps a username to an internal email identity at the Supabase project's own host. That mode requires email confirmation off and must run only against a dedicated development project; internal aliases cannot receive recovery messages. The previous `@auth.deardiary.invalid` alias was rejected because Supabase blocks reserved test domains. Do not use the shared `12345678` test password for real accounts.

## Project configuration

The ignored local file `ios/.env` contains the production project URL and publishable key. The separate ignored file `ios/.env.development` contains the development project's client URL and publishable key. Flutter does not load `.env` files automatically. Keep these files local; neither should be committed. The username-only mode must use only `.env.development`:

```powershell
$ddConfig = @{}
Get-Content 'ios/.env.development' | ForEach-Object {
  if ($_ -match '^([^=]+)=(.*)$') { $ddConfig[$matches[1]] = $matches[2] }
}
flutter run --dart-define="SUPABASE_URL=$($ddConfig.project_URL)" --dart-define="SUPABASE_ANON_KEY=$($ddConfig.publishable_key)" --dart-define=USERNAME_ONLY_AUTH=true
```

For an Android release build:

```powershell
$ddConfig = Get-Content 'ios/.env' | ConvertFrom-StringData
flutter build apk --release --dart-define="SUPABASE_URL=$($ddConfig.project_URL)" --dart-define="SUPABASE_ANON_KEY=$($ddConfig.publishable_key)"
```

For GitHub release builds, add repository **Actions variables** named `SUPABASE_URL` and `SUPABASE_ANON_KEY` under **Settings → Secrets and variables → Actions → Variables**. These are client connection settings (the URL and publishable key), not an admin/service-role credential. The release workflow now stops with a clear message if either variable is missing and passes both values into Android and iOS builds.

The publishable/anon key is intended for client apps; the SQL migration uses RLS and authenticated RPCs. Never put a Supabase `service_role` or secret key in Flutter, `.env` shipped with the app, GitHub, or a release artifact. `.env` is Git-ignored; verify with `git check-ignore ios/.env`.

## Supabase dashboard setup

1. Use the dedicated **Dear Diary Dev** project for username-only testing. Do not use production data.
2. Email confirmation is disabled only on the dev project, so signup does not send an email. Supabase documents that disabling confirmation implicitly confirms the email.
3. The migration and Realtime publication have already been applied to this dev project. `Success. No rows returned` is normal for DDL; it means the statement did not return a result grid, not that it returned zero inserted records. To check the core tables, run:

   ```sql
   select table_name
   from information_schema.tables
   where table_schema = 'public'
     and table_name in ('profiles', 'friend_requests', 'conversations', 'conversation_members', 'messages', 'message_receipts')
   order by table_name;
   ```

4. The five app Realtime tables have already been added to `supabase_realtime`. To inspect them, run:

   ```sql
   select schemaname, tablename
   from pg_publication_tables
   where pubname = 'supabase_realtime'
   order by tablename;
   ```

   You can also enable these five tables under **Database → Publications → supabase_realtime**. Realtime is disabled for new tables until they are added to the publication. [Supabase's Flutter Realtime guide](https://supabase.com/docs/guides/realtime/realtime-listening-flutter)
5. Build the app with the development project's URL and publishable key. On Windows, `ios/.env.development` is read only by the PowerShell build command in this guide; the app itself does not read `.env`.
6. The live backend check has already created/signed in `user1` and `user2`, sent and accepted a friend request, delivered and read a message, and verified its read receipt. Install the same configured build on two devices to check the UI and realtime behavior. Each handle must be unique in that Supabase project.

The screenshot you shared labels the Supabase project branch **PRODUCTION**. Keep confirmation enabled there and configure custom SMTP before registering users outside the Supabase organization. For rapid username-only testing, use a separate development project, apply the migration, disable confirmation there, then build with `--dart-define=USERNAME_ONLY_AUTH=true`. The Auth request limit still applies: stop repeated retries and wait at least five minutes before testing again. Supabase lets project owners adjust per-IP Auth limits under **Authentication → Rate Limits**; make changes only in the development project. The built-in email provider is limited to two Auth emails per hour; custom SMTP is required to raise that email quota. [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits) [Supabase Auth configuration](https://supabase.com/docs/guides/auth/general-configuration)

## Build a username-only Android test APK

Run this from the repository root in PowerShell; it reads the already-created dev configuration and leaves production `ios/.env` alone:

```powershell
$ddConfig = @{}
Get-Content 'ios/.env.development' | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
    $ddConfig[$matches[1]] = $matches[2].Trim('"').Trim("'")
  }
}
flutter build apk --debug `
  --dart-define="SUPABASE_URL=$($ddConfig['project_URL'])" `
  --dart-define="SUPABASE_ANON_KEY=$($ddConfig['publishable_key'])" `
  --dart-define=USERNAME_ONLY_AUTH=true
```

The universal test APK appears at `build/app/outputs/flutter-apk/app-debug.apk` and includes ARM64 support for normal Android phones as well as emulator architectures. It asks only for username/password. Each new account receives an internal Auth identity at the development project's host; no email can be delivered or used for recovery. Do not build this mode against the production project's URL/key.

## Data and privacy limits

- Supabase Auth stores password verifiers; the app does not store account passwords in its chat preferences.
- The migration's message and diary bodies are plaintext at the database/provider. RLS controls which authenticated accounts can query rows, but this is not end-to-end encryption and project administrators/providers can access data.
- Media, voice notes, location sharing, edit history, and attachment export are not connected to the database schema.
- The migration supports exact friend-request RPCs and retaining conversation rows after `end_friendship`; the app calls the request/message/receipt RPCs. Unfriend is exposed in the service, but media and several planned behaviors are still absent.
- No Supabase service key is present in the app configuration, and none is needed for the client flow.
