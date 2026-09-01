# Release Checklist

## One-step GitHub publish decision

1. Click: `Settings -> Pages -> Build and deployment -> Source -> GitHub Actions`
2. Run: `git push -u origin main`
3. Live URL: `https://shir-openu.github.io/RES-QUILL/`

## GitHub Pages

1. In GitHub, open `shir-openu/RES-QUILL`.
2. Click `Settings -> Pages -> Build and deployment -> Source -> GitHub Actions`.
3. Confirm the local `main` branch includes `.github/workflows/deploy-web.yml`.
4. Push `main` to `origin`.
5. Open `Actions` and wait for `Deploy Flutter Web` to finish.
6. Visit `https://shir-openu.github.io/RES-QUILL/`.

Note on the URL, and on a mistake worth recording. The project page is served below the
repository name, and that path is case sensitive. The git remote read
`shir-openu/res-quill`, lower case, so the checklist was changed to match it. That was
wrong: the repository had been renamed to `RES-QUILL` and GitHub was still answering the
old lower-case URL with a redirect. The first push revealed it - `remote: This repository
moved`. The correct name is `RES-QUILL` and the remote has been corrected.

The workflow no longer hard-codes either spelling. It builds with
`--base-href "/${{ github.event.repository.name }}/"`, taking the name from GitHub itself,
so it is right whatever the repository is called and cannot drift again.

## Google Play

1. Choose the final app name, icon, package name, and privacy policy URL.
2. Create a release keystore and keep passwords outside git.
3. Configure Android release signing in `android/`.
4. Accept Android SDK licences if the build machine asks.
5. Run `flutter build appbundle --release`.
6. Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console.
7. Complete the Play listing, data safety, content rating, and screenshots.
8. Run the required Play testing track, then promote to production.
