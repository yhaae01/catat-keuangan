# Catat Keuangan

Aplikasi pencatatan pemasukan dan pengeluaran berbasis Flutter. Transaksi dapat dicatat manual atau dibuat dari foto struk menggunakan OCR.

## Fitur

- Catat transaksi pemasukan dan pengeluaran, termasuk beberapa item, jumlah, dan harga satuan.
- Harga satuan ditampilkan dengan pemisah ribuan, misalnya `125.000`.
- Pindai struk melalui kamera atau pilih gambar dari galeri. Dari dashboard, pilihan **Scan Struk Belanja** langsung membuka mode scan.
- OCR Google ML Kit membaca teks struk. Parser aplikasi membantu mengambil nama toko, item, nominal, dan mencocokkan kategori; kategori baru dapat dibuat jika tidak ditemukan.
- Jika berpindah mode saat form berisi data, aplikasi meminta konfirmasi sebelum mengosongkan form. Item yang berisi data juga meminta konfirmasi sebelum dihapus; item kosong dapat langsung dihapus.
- Kategori pemasukan dan pengeluaran dapat dikelola, sementara transaksi disimpan secara lokal menggunakan Hive.

## Teknologi

- Flutter dan Dart
- Provider untuk state management
- Hive untuk penyimpanan lokal
- Google ML Kit Text Recognition dan `image_picker` untuk pemindaian struk
- `intl` untuk format mata uang dan tanggal

## Menjalankan Aplikasi

Prasyarat: [Flutter SDK](https://docs.flutter.dev/get-started/install) dengan Dart SDK yang sesuai dengan batas versi di `pubspec.yaml`, serta Android Studio atau perangkat Android untuk menjalankan aplikasi.

Di direktori proyek, jalankan:

```bash
flutter pub get
flutter run
```

Fitur OCR memerlukan platform yang didukung oleh `google_mlkit_text_recognition` (Android dan iOS).

## Pengujian dan Build

Jalankan pengujian:

```bash
flutter test
```

Buat APK release Android:

```bash
flutter build apk --release
```