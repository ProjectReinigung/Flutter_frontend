# Deployment

## Configuration

Local development uses localhost by default:

```sh
flutter run
```

Production builds use Dart defines. The GitHub Actions workflows already pass:

```sh
--dart-define=APP_ENV=production
--dart-define=API_BASE_URL=https://api.karakheti.de
--dart-define=KEYCLOAK_URL=https://auth.karakheti.de
--dart-define=KEYCLOAK_REALM=cleaning-system
--dart-define=KEYCLOAK_CLIENT_ID=cleaning-system-frontend
--dart-define=REDIRECT_URL=https://projectreinigung.github.io/Flutter_frontend/
```

If the production Keycloak client has a different client ID, update `KEYCLOAK_CLIENT_ID` in both workflows and in your local production build command.

## GitHub Pages

Push to `main` to deploy the web app:

```sh
git push origin main
```

The workflow builds with:

```sh
flutter build web --release --base-href /Flutter_frontend/
```

It deploys `build/web` to:

```text
https://projectreinigung.github.io/Flutter_frontend/
```

The workflow also copies `index.html` to `404.html` so GitHub Pages can serve the Flutter app after browser refreshes on client-side routes.

## GitHub Releases

Create and push a semantic version tag:

```sh
git tag v1.0.0
git push origin v1.0.0
```

The release workflow uploads:

```text
cleaning-app-android.apk
cleaning-app-windows.zip
```

These files appear on the GitHub Release for the pushed tag in:

```text
https://github.com/ProjectReinigung/Flutter_frontend/releases
```

## Android

The Android application ID is:

```text
de.karakheti.cleaning_manager
```

Release APKs currently use Flutter's generated debug signing config, which is enough for internal testing. Before publishing to the Play Store, add an upload keystore, store its passwords as GitHub Actions secrets, configure `android/key.properties`, and switch the Gradle `release` signing config away from debug signing.

## Windows

Windows desktop support is present in the `windows/` directory. The release workflow builds:

```sh
flutter build windows --release
```

It zips the contents of:

```text
build/windows/x64/runner/Release
```

## Keycloak Client

Configure the production Keycloak client with:

```text
Valid redirect URI: https://projectreinigung.github.io/Flutter_frontend/*
Web origin: https://projectreinigung.github.io
```
