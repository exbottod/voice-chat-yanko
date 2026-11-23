# Resource Android kustom

Folder `native/android/res/` isinya disalin ke `android/app/src/main/res/` saat build CI,
menimpa resource bawaan Flutter.

Taruh file di sini dengan struktur yang sama seperti folder `res` Android:

```
native/android/res/
  mipmap-mdpi/ic_launcher.webp
  mipmap-hdpi/ic_launcher.webp
  mipmap-xhdpi/ic_launcher.webp
  mipmap-xxhdpi/ic_launcher.webp
  mipmap-xxxhdpi/ic_launcher.webp
  drawable/logo.png
  values/colors.xml
```

Ukuran ikon launcher standar:

| Folder | Ukuran |
| --- | --- |
| mipmap-mdpi | 48x48 |
| mipmap-hdpi | 72x72 |
| mipmap-xhdpi | 96x96 |
| mipmap-xxhdpi | 144x144 |
| mipmap-xxxhdpi | 192x192 |

Untuk adaptive icon (Android 8+), tambahkan `mipmap-anydpi-v26/ic_launcher.xml`
plus `drawable/ic_launcher_background` dan `drawable/ic_launcher_foreground`.

Catatan: pakai aset milik sendiri, jangan mengambil ikon dari APK aplikasi lain.
