# 💰 Expense Tracker AI (Scan Struk Auto-Categorize)

Aplikasi pencatatan keuangan pribadi pintar berbasis **Flutter** yang dilengkapi fitur kategori dinamis dan pemindaian struk berbasis AI/OCR untuk pencatatan otomatis secara *real-time*.

---

## ✨ Fitur Utama

- 📥 **Catat Pemasukan & Pengeluaran:** Pencatatan transaksi manual yang cepat dan intuitif.
- 🏷️ **Kategori Dinamis:** Bebas menambah, mengedit, atau menghapus kategori pemasukan & pengeluaran sesuai kebutuhan.
- 🧾 **OCR / Auto-Scan Struk:** Ambil foto atau *upload screenshot* struk belanja, aplikasi akan otomatis membaca total nominal dan mendeteksi kriteria transaksi.
- 🤖 **Auto-Category Detection:** AI/Text Parser cerdas yang bisa menebak kategori atau otomatis buat kategori baru jika belum tersedia.
- 💾 **Local Offline Storage:** Menggunakan **Hive Database** sehingga data tersimpan cepat, aman, dan dapat diakses offline.

---

## 🛠️ Tech Stack & Dependencies

- **Framework:** Flutter (Dart)
- **State Management:** `flutter_bloc` / `provider`
- **Database Local:** `hive_flutter`
- **OCR / AI Text Recognition:** `google_mlkit_text_recognition`
- **Image Picker:** `image_picker`
- **Utilities:** `intl`, `uuid`, `path_provider`

---

## 🚀 Cara Menjalankan Project

### 1. Prasyarat
Pastikan kamu sudah menginstal:
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio / VS Code + Flutter Extension

### 2. Clone & Setup Project
```bash
# Clone repository ini (jika menggunakan git)
git clone [https://github.com/username/expense_tracker_ai.git](https://github.com/username/expense_tracker_ai.git)

# Masuk ke direktori project
cd expense_tracker_ai

# Install seluruh dependency
flutter pub get