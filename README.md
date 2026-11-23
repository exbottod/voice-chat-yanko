# Voice Chat Yanko

Aplikasi voice chat room hybrid: **UI Flutter**, dengan lapisan native **Kotlin + Java** di Android.

## Isi kode

- `lib/login_page.dart` - layar login (Google Login, tombol akun, tombol nomor HP)
- `lib/register_page.dart` - layar daftar akun (nama + nomor HP)
- `lib/main.dart` - UI Flutter (daftar room + layar voice chat)
- `lib/native_bridge.dart` - MethodChannel Dart ke native
- `native/android/kotlin/.../MainActivity.kt` - entry Activity, mendaftarkan channel
- `native/android/kotlin/.../VoiceChannelBridge.kt` - handler MethodChannel (Kotlin)
- `native/android/java/.../AudioRouteHelper.java` - helper AudioManager (Java)
- `.github/workflows/build-apk.yml` - CI build APK otomatis

Channel yang dipakai: `yanko/voice`
Method: `getAudioRoute`, `setSpeakerphone`, `ping`

## Aset gambar

`assets/images/` berisi 151 gambar (webp/png) hasil ekstrak aset aplikasi Yanko milik owner:
room background, boss throne, crown, gift button, seat coin pill, room tools, emotes, VIP,
ranking, koin, dan lainnya. Daftar path penting ada di `lib/app_assets.dart`.

`assets/fonts/` berisi Baloo2 800 dan Quicksand 700 (Google Fonts, lisensi OFL).

## Branding

- Nama brand ada di `kBrandName` dalam `lib/login_page.dart`
- Maskot/logo: ganti file `assets/mascot.png` lalu isi widget `_Mascot`

## Firebase

- `native/android/google-services.json` - konfigurasi Firebase (project `login-9604e`)
- `tool/apply_firebase.py` - menyalin file di atas ke `android/app/`, mengubah `applicationId`
  menjadi `com.exceoid.voiceyanko`, menaikkan `minSdk` ke 23, dan mengaktifkan plugin Gradle
  `com.google.gms.google-services`

`lib/main.dart` memanggil `Firebase.initializeApp()`. Kalau konfigurasi tidak cocok,
aplikasi tetap jalan dan hanya menampilkan "Firebase belum aktif".

## Build APK tanpa PC (lewat HP)

1. Push ke branch `main` (atau jalankan manual di tab Actions).
2. Buka tab **Actions** di repo ini.
3. Buka run terbaru, unduh artifact **voice-chat-yanko-apk**.
4. Extract, install salah satu `app-*-release.apk` sesuai arsitektur HP (biasanya `arm64-v8a`).

## Build lokal (kalau ada PC)

```bash
flutter create --platforms=android --org com.exbottod --project-name voice_chat_yanko .
cp -r native/android/kotlin/. android/app/src/main/kotlin/
cp -r native/android/java/. android/app/src/main/java/
flutter pub get
flutter build apk --release
```
