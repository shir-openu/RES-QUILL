# Release Checklist

## GitHub Pages

1. In GitHub, open `shir-openu/res-quill`.
2. Click `Settings -> Pages -> Source = GitHub Actions`.
3. Confirm the local `main` branch includes `.github/workflows/deploy-web.yml`.
4. Push `main` to `origin`.
5. Open `Actions` and wait for `Deploy Flutter Web` to finish.
6. Visit `https://shir-openu.github.io/RES-QUILL/`.

## Google Play

1. Choose the final app name, icon, package name, and privacy policy URL.
2. Create a release keystore and keep passwords outside git.
3. Configure Android release signing in `android/`.
4. Accept Android SDK licences if the build machine asks.
5. Run `flutter build appbundle --release`.
6. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.
7. Complete the Play listing, data safety, content rating, and screenshots.
8. Run the required Play testing track, then promote to production.
