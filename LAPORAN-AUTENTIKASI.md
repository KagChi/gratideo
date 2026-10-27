# Laporan fitur login dan register Gratideo

## Ringkasan

Versi aplikasi: **0.2.0+2**. Halaman masuk dan daftar mengikuti desain Gratideo yang sudah ada: Morning Gold/Night Watch, latar krem atau gelap, aksen emas, judul Playfair Display, dan teks DM Sans. Layout menyesuaikan layar ponsel biasa serta layar Fold yang terbuka.

## Yang dikerjakan

- Halaman **Sign in** dan **Create account**, dengan validasi nama, format email, panjang password, konfirmasi password, dan tombol tampil/sembunyikan password.
- Halaman **Forgot password** beserta titik integrasi ke layanan reset password. Pengiriman email belum tersedia tanpa backend.
- Alur masuk otomatis setelah register/login, sesi masuk yang tersimpan di perangkat, dan **Sign out** melalui Settings.
- AuthService memisahkan tampilan dari logika akun agar implementasi lokal dapat diganti oleh implementasi API/backend.

## File yang diubah atau ditambahkan

- lib/screens/auth_screen.dart — tampilan masuk, daftar, dan lupa password.
- lib/services/auth.dart — kontrak autentikasi dan implementasi akun lokal.
- lib/widgets/auth_scope.dart — akses status akun dari layar Settings.
- lib/main.dart dan lib/app.dart — memuat status akun dan memilih layar awal.
- lib/screens/settings_screen.dart — status akun dan tombol keluar.
- pubspec.yaml dan pubspec.lock — dependensi crypto, versi paket, dan nomor versi 0.2.0+2.
- test/widget_test.dart — tes register, password salah, logout, dan login ulang.

File konten bawaan di assets/data dan assets/audio, serta layar Today, Prayers, Thanks, Journal, Remember, dan Selah **tidak diubah**.

## Data untuk mencoba APK

**Tidak ada akun bawaan.** Di setiap handphone, buka aplikasi dan pilih **Create account**. Contoh input:

| Isian | Contoh |
| --- | --- |
| Nama | Penguji Gratideo |
| Email | penguji@gratideo.app |
| Password | Gratideo2026! |

Setelah mendaftar, buka **Settings → Sign out**, lalu coba **Sign in** dengan email dan password yang sama. Satu instalasi hanya menyimpan satu akun lokal. Password tidak disimpan sebagai teks; aplikasi menyimpan salt dan verifikator PBKDF2-HMAC-SHA256 lokal.

**Lintas handphone:** APK yang sama dapat dipasang di beberapa handphone, tetapi setiap instalasi memiliki akun lokal dan data sendiri. Email contoh yang sama dapat didaftarkan di setiap handphone, namun itu **bukan satu akun yang tersinkronisasi**. Doa, ucapan syukur, jurnal, nama, dan pengaturan pada satu handphone tidak muncul di handphone lain. Konten bawaan tetap tersedia pada setiap instalasi: 385 ayat dan 59 confession.

## Yang perlu dikerjakan bersama backend

1. Implementasikan AuthService dengan endpoint register, login, sesi/token, logout, dan reset password melalui email.
2. Ganti LocalAuthService.load(settings) di lib/main.dart dengan implementasi backend.
3. Tentukan penyimpanan token yang aman dan pemulihan sesi setelah aplikasi dibuka ulang.
4. Kaitkan doa, ucapan syukur, jurnal, dan pengaturan ke ID pengguna, lalu rancang sinkronisasi serta migrasi data lokal yang sudah ada.
5. Tentukan alur akun ganda dan pemulihan password. Pada versi lokal ini satu perangkat hanya bisa mendaftar satu akun dan email reset belum dikirim.

## Verifikasi

- flutter analyze --no-fatal-infos: tidak ada error atau warning; lima catatan gaya yang sudah ada di layar lama tetap muncul.
- flutter test: tes akun lokal lulus.
- flutter build apk --release: APK berhasil dibuat.
- APK bertanda tangan dengan **debug key** dari proyek Flutter yang dihasilkan. Ini cocok untuk uji instalasi, belum untuk publikasi Play Store.
- Belum ada perangkat Android yang terhubung, jadi perilaku pada perangkat fisik belum diuji.

## Artifact

- APK instalasi: Gratideo-v0.2.0-auth.apk (65,9 MB menurut output Flutter; minimum Android API 24).
- SHA-256 APK: 203655a749cb244971e94e9e459a56a9dcde717b21f37b54cd0a98a2cae8ea12.
- Arsip sumber untuk handoff backend: Gratideo-auth-source-v0.2.0.zip (di folder Downloads).
