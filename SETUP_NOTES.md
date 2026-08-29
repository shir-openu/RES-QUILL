# Res-Quill Setup Notes

## Local Work Completed

Commands run from `D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\GITHUB_REPO_FOR_FLUTTER_RES-QUILL`:

```powershell
git init
git branch -M main
& "C:\flutter\bin\flutter.bat" --version
& "C:\flutter\bin\flutter.bat" config --enable-web
& "C:\flutter\bin\flutter.bat" config --enable-windows-desktop
& "C:\flutter\bin\flutter.bat" config --enable-android
& "C:\flutter\bin\flutter.bat" create --empty --platforms=android,windows,web --project-name=res_quill --org=com.shirsivroni --description="Res-Quill: guided t-test reporting for learners." .
& "C:\flutter\bin\dart.bat" format lib
& "C:\flutter\bin\flutter.bat" analyze
& "C:\flutter\bin\flutter.bat" build web --base-href /res-quill/
& "C:\flutter\bin\flutter.bat" build windows
```

Manual local edits after scaffold:

- Forced Android `namespace` and `applicationId` to `com.shirsivroni.resquill`.
- Moved `MainActivity.kt` to `android\app\src\main\kotlin\com\shirsivroni\resquill`.
- Set Android, Windows, and Web user-visible names to `Res-Quill`.
- Added `lib\src\app_constants.dart` as the one Dart source for the display name and slogan.
- Replaced the empty app body with a minimal centered placeholder screen.
- Added `kotlin.incremental=false` in `android\gradle.properties`.
- Hardened `.gitignore` for `build/`, `.dart_tool/`, `.gradle/`, `.kotlin/`, and Dropbox conflict files.
- Added `.github\workflows\deploy-web.yml`.
- Added `web\.nojekyll`.
- Added `web\flutter_bootstrap.js` with `_flutter.loader.load();` and no `serviceWorkerSettings`.

## Values That Must Not Drift

- Display name: `Res-Quill`
- Slogan: `From statistical output to clear reporting.`
- Dart package name: `res_quill`
- Android namespace: `com.shirsivroni.resquill`
- Android applicationId: `com.shirsivroni.resquill`
- Kotlin package: `com.shirsivroni.resquill`
- GitHub repository: `shir-openu/res-quill`
- Remote URL: `https://github.com/shir-openu/res-quill.git`
- GitHub Pages URL: `https://shir-openu.github.io/res-quill/`
- GitHub Pages base href: `/res-quill/`
- Flutter SDK command: `C:\flutter\bin\flutter.bat`
- Flutter version: `3.41.6`
- Dart version: `3.11.4`
- Platforms in this scaffold: `android`, `windows`, `web`
- Palette: background `#0F172A`, surface `#1E293B`, cyan `#22D3EE`, violet `#A78BFA`, green `#34D399`, error `#FF6B6B`

## GitHub Pages Deployment

The workflow builds web on pushes to `main`, uploads `build/web`, and deploys with GitHub Pages Actions.

The workflow build command is:

```bash
flutter build web --release --base-href /res-quill/
```

`/res-quill/` is required because this is a GitHub Pages project page. If it is changed to `/` or another path, Flutter bootstrap and asset URLs resolve from the wrong location and the deployed page can load blank.

Service-worker choice: no offline-first service worker is registered. `web\flutter_bootstrap.js` intentionally omits `serviceWorkerSettings`, and the workflow removes the generated `build/web/flutter_service_worker.js` before upload. This avoids serving stale cached Pages builds.

The workflow also creates `build/web/.nojekyll` before upload so GitHub Pages serves Flutter files whose paths may include leading underscores.

## Shir Push Commands

Run these only after Shir creates the public GitHub repository `shir-openu/res-quill`:

```powershell
cd /d D:\Dropbox\1PIPELINES1\FLUTTER_RESQUIL\GITHUB_REPO_FOR_FLUTTER_RES-QUILL
git remote -v
git status
git push -u origin main
```

Do not run `git add .` from the parent research folder. The git root is this folder only.

## Required GitHub Pages Setting

In GitHub, open:

`shir-openu/res-quill` -> `Settings` -> `Pages` -> `Build and deployment` -> `Source` -> `GitHub Actions`

If Source is left on branch publishing, the Pages workflow can succeed while the public site remains stale or empty.

## Verification Results

- `flutter analyze`: passed with zero issues.
- `flutter build web --base-href /res-quill/`: passed.
- Built web index exists: `build\web\index.html`.
- Built web base href: `<base href="/res-quill/">`.
- Built web `.nojekyll` exists after local build.
- `flutter build windows`: passed.
- Windows executable: `build\windows\x64\runner\Release\res_quill.exe`.
- Android id grep: no `com.shirsivroni.res_quill` remains under `android`.
- Hebrew grep: no Hebrew characters found in the repo.

## Not Verified

- UNKNOWN: GitHub repository existence. No repo was created.
- UNKNOWN: GitHub Actions run result. No push was performed.
- UNKNOWN: live GitHub Pages deployment. No push was performed.
- UNKNOWN: Android build result. Android build was not attempted for this local step.
