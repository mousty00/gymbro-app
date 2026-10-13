# Deploy

How to build GymBro for release and publish it on the App Store and Google Play.

The app talks to [gymbro-api](https://github.com/mousty00/gymbro-api); deploy that first (see
its `DEPLOY.md`) so you have an HTTPS base URL like `https://api.<domain>/api`.

| | iOS | Android |
|---|---|---|
| App id | `com.mousty.gymbro` | `com.mousty.gymbro` |
| Minimum OS | iOS 15.0 | Flutter's default `minSdk` |
| Push | APNs directly, no Firebase | FCM (`google-services.json`) |
| Release artifact | `.ipa` | `.aab` (App Bundle) |
| Store account | Apple Developer Program (99 USD/year) | Google Play Console (25 USD once) |

## 1. Build configuration

### API URL

The base URL is compiled in with `--dart-define` (`lib/core/config/env.dart`). Without it the app
points to `http://localhost:8080/api`, which release builds can't even reach (they only allow
`https://`). **Every release command below must pass it:**

```bash
--dart-define=API_BASE_URL=https://api.<domain>/api
```

Release builds never use the mock backend: the "Usa dati demo" button only exists in debug.

### Map tiles (running)

The running maps use [flutter_map](https://pub.dev/packages/flutter_map) with raster tiles. The
default is the public OpenStreetMap server, which is fine for development but **forbids
published-app traffic** ([tile usage policy](https://operations.osmfoundation.org/policies/tiles/)).
For release, take a free key from a tile provider and pass its URL and attribution:

```bash
# MapTiler (free tier: 100k tiles/month)
--dart-define=MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=<key>
--dart-define=MAP_ATTRIBUTION="© MapTiler © OpenStreetMap contributors"
```

Stadia Maps or Thunderforest work the same way. Restrict the key to the app's bundle id /
package name in the provider's dashboard, since it ships inside the app. Snapping routes to
streets is done by the API (`ROUTING_ORS_API_KEY`, see the API's `DEPLOY.md`): no routing key in
the app.

### Version

`pubspec.yaml` → `version: 1.0.0+1` is `<name>+<build>`. The name is what users see; the build
number must go up on **every** upload to either store, or the upload is rejected. Bump it in
`pubspec.yaml`, or override per build with `--build-name=1.0.1 --build-number=2`.

### Optional: obfuscation

Add `--obfuscate --split-debug-info=build/symbols` to the build commands, and keep
`build/symbols` for each release: you need it to read crash stack traces.

## 2. iOS and App Store

Requires a Mac with Xcode and an Apple Developer Program membership.

### One-time setup

1. **App ID.** [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list)
   → Identifiers → **+** → App IDs → bundle id `com.mousty.gymbro`, enable the
   **Push Notifications** capability.
2. **APNs key** for the API: Keys → **+** → Apple Push Notifications service. The `.p8` goes only
   on the server (`APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`, see the API's `DEPLOY.md`), never
   in the app.
3. **Signing.** Open `ios/Runner.xcworkspace` in Xcode → Runner target → **Signing &
   Capabilities** → pick your Team. Signing is set to Automatic, so Xcode creates the
   certificates and profiles. Push Notifications should show as a capability (the entitlement is
   in `ios/Runner/Runner.entitlements`). It says `aps-environment = development`; that's correct,
   Xcode switches it to production when it signs the build for App Store distribution.
4. **App record.** [App Store Connect](https://appstoreconnect.apple.com) → Apps → **+** → New
   App: platform iOS, name, primary language, bundle id `com.mousty.gymbro`, a SKU of your choice.
5. **Export compliance.** The app only uses standard HTTPS. To skip the encryption question on
   every upload, add this to `ios/Runner/Info.plist`:

   ```xml
   <key>ITSAppUsesNonExemptEncryption</key>
   <false/>
   ```

### Build and upload

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.<domain>/api
```

This produces `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/*.ipa`. Upload with either:

- Xcode: `open build/ios/archive/Runner.xcarchive` → Organizer → **Distribute App** → App Store
  Connect, or
- the **Transporter** app (Mac App Store): drag in the `.ipa`.

After processing (a few minutes to an hour) the build appears in App Store Connect.

### TestFlight

App Store Connect → your app → **TestFlight**. Internal testers (up to 100 people on your team)
can install right away; external testers need a short Beta App Review first.

Push on TestFlight and App Store builds uses **production** APNs, so the API must run with
`APNS_SANDBOX=false`. Builds run straight from Xcode use the sandbox and won't get pushes from
the production API.

### Submit for review

On the app's version page fill in:

- Screenshots: 6.9" iPhone (1320 × 2868) are required; iPad only if you ship for iPad. The app
  currently supports iPad orientations in `Info.plist`, so App Store Connect will ask for iPad
  screenshots too unless you remove iPad from the target's supported destinations.
- Description, keywords, support URL, **privacy policy URL** (required).
- **App Privacy**: the app collects email, username, photos, workout data, **precise location**
  (only while recording a run, saved as the run's track) and a device push token, all linked to
  the user and not used for tracking.
- **Location in background**: the app declares the `location` background mode so a run keeps
  recording with the screen off. It only asks for "While Using" permission and starts updates
  from a visible screen, with the blue indicator on. In the review notes, say: "Location is used
  only while the user records a run they started from the Run screen, to measure distance and
  pace and save the route; it keeps working with the screen locked until the user taps Fine."
  A short screen recording of starting a run helps.
- Age rating questionnaire. The app has user-generated content (posts, comments).
- **Sign-In Information**: login is required, so give the reviewer a working demo account
  (username and password). Signup needs an OTP by email, which the reviewer can't receive.
- Select the build, then **Add for Review** → **Submit**.

Review notes worth knowing before you submit:

- Account deletion (guideline 5.1.1(v)) is in the app (Profile), good.
- User-generated content (guideline 1.2) needs a way to **block** users (present) and to
  **report** objectionable posts or comments, plus a contact for reports. There's no report
  button yet; expect a rejection until there is one.

## 3. Android and Google Play

### One-time setup

#### Upload key

Play needs every upload signed with your own key. Today `android/app/build.gradle.kts` signs
release builds with the **debug** key, which Play rejects.

1. Create the key once and back it up somewhere safe (losing it means asking Google for an
   upload key reset):

   ```bash
   keytool -genkey -v -keystore ~/gymbro-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (already in `.gitignore`, never commit it):

   ```properties
   storePassword=<store password>
   keyPassword=<key password>
   keyAlias=upload
   storeFile=/Users/<you>/gymbro-upload.jks
   ```

3. In `android/app/build.gradle.kts`, load it and use it for release builds. Keep the debug
   fallback so CI, which has no key, still builds:

   ```kotlin
   import java.util.Properties

   val keystoreProperties = Properties().apply {
       val file = rootProject.file("key.properties")
       if (file.exists()) file.inputStream().use { load(it) }
   }

   android {
       // ...
       signingConfigs {
           if (keystoreProperties.isNotEmpty()) {
               create("release") {
                   keyAlias = keystoreProperties.getProperty("keyAlias")
                   keyPassword = keystoreProperties.getProperty("keyPassword")
                   storeFile = file(keystoreProperties.getProperty("storeFile"))
                   storePassword = keystoreProperties.getProperty("storePassword")
               }
           }
       }
       buildTypes {
           release {
               signingConfig = if (keystoreProperties.isNotEmpty())
                   signingConfigs.getByName("release")
               else
                   signingConfigs.getByName("debug")
           }
       }
   }
   ```

On the first upload, accept **Play App Signing**: Google keeps the app signing key and your
`.jks` is only the upload key.

#### Push (FCM)

1. [Firebase console](https://console.firebase.google.com) → create a project → add an
   **Android** app with package `com.mousty.gymbro` (no iOS app: iOS uses APNs directly).
2. Download `google-services.json` into `android/app/`. The Gradle build applies the Google
   Services plugin only when that file exists, so without it the app builds the same and just
   never gets a push token.
3. Generate a service account key (Project settings → Service accounts) and set it on the API as
   `FCM_SERVICE_ACCOUNT_JSON`.

On Android 13+ the app asks for the notification permission (`POST_NOTIFICATIONS`) at runtime.

#### App record

[Play Console](https://play.google.com/console) → **Create app**: name, default language, App,
Free. Then work through **Dashboard → Set up your app**:

- Privacy policy URL.
- **App access**: login is required, so add demo credentials for the reviewer.
- Ads: no.
- Content rating questionnaire (mention user-generated content).
- Target audience.
- **Data safety**: email, username, photos, fitness data, **precise location** (run tracks),
  device id (push token); collected, encrypted in transit, not shared, deletable by the user.
- **Location / foreground service**: the app uses a `location` foreground service (from
  geolocator) only while a run is recording, with a persistent notification. Play Console asks
  you to declare `FOREGROUND_SERVICE_LOCATION` under **App content → Foreground service
  permissions**: choose the user-initiated location task and attach a short video of starting a
  run. No `ACCESS_BACKGROUND_LOCATION` is requested, so there's no background location
  declaration.
- **Account deletion**: Play also asks for a **web link** where users can request deletion
  without the app. In-app deletion alone isn't enough; a simple page with a contact form or
  email address works.
- Store listing: short and full description, 512 × 512 icon, 1024 × 500 feature graphic, at
  least 2 phone screenshots.

### Build and upload

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.<domain>/api
```

Upload `build/app/outputs/bundle/release/app-release.aab` in Play Console → **Testing** (or
**Production**) → Create new release.

### Testing tracks and going live

- **Internal testing**: up to 100 testers, available in minutes, no review. Start here.
- **Closed testing**: a new **personal** developer account must run a closed test with at least
  **12 testers opted in for 14 consecutive days** before it can apply for production access.
  Organization accounts skip this.
- **Production**: after review (usually hours to a few days).

## 4. Release checklist

- [ ] API deployed and healthy on `https://api.<domain>/api`, SMTP and S3 tested with a signup
- [ ] `APNS_*` set with `APNS_SANDBOX=false`, `FCM_SERVICE_ACCOUNT_JSON` set; API logs show both
      push channels enabled
- [ ] Version and build number bumped in `pubspec.yaml`
- [ ] Built with `--dart-define=API_BASE_URL=https://api.<domain>/api`
- [ ] Built with `MAP_TILE_URL` / `MAP_ATTRIBUTION` of a tile provider with a key (not the public OSM server)
- [ ] `ROUTING_ORS_API_KEY` set on the API, so routes follow the streets
- [ ] Android: signed with the upload key, `google-services.json` in `android/app/`
- [ ] iOS: Push Notifications capability on, `ITSAppUsesNonExemptEncryption` set
- [ ] Privacy policy URL and (for Play) account-deletion URL online
- [ ] Demo account for reviewers, with some data in it
- [ ] Report button for posts and comments (App Store guideline 1.2)
- [ ] Tested the release build on a real device: login, push received, photo upload

## CI

`.github/workflows/ci.yml` runs analyze and unit tests, builds a release APK (debug-signed, not
publishable) and compiles iOS without signing. It doesn't publish anything; store uploads are
manual with the commands above.
