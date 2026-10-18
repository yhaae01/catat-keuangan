import 'dart:math';
import '../../data/models/category_model.dart';
import '../../data/models/receipt_item_model.dart';
import '../../data/models/transaction_type.dart';
import '../../logic/providers/category_provider.dart';

class ReceiptParserHelper {
  /// Ekstrak angka terbesar dari teks struk sebagai total nominal
  static double extractLargestAmount(String rawText) {
    if (rawText.trim().isEmpty) return 0.0;

    final candidates = <double>[];
    final lines = rawText.split('\n');

    // Regex untuk mengenali format mata uang dan angka:
    // Contoh: "Rp 150.000", "Rp. 150.000,00", "150,000.00", "150.000", "150000"
    final regex = RegExp(
      r'(?:Rp\.?|IDR)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]+)',
      caseSensitive: false,
    );

    for (final line in lines) {
      final matches = regex.allMatches(line);
      for (final match in matches) {
        final matchStr = match.group(1);
        if (matchStr == null) continue;

        final cleanedAmount = _parseFormattedNumber(matchStr);
        if (cleanedAmount != null) {
          // Filter out angka yang kemungkinan bukan nominal belanja:
          // 1. Nomor HP (biasanya 10-13 digit, atau diawali 08)
          // 2. Barcode / No Resi / Serial number (> 10 digit tanpa desimal)
          // 3. Angka tahun (2020 - 2035) jika berdiri sendiri di baris tanggal
          if (_isLikelyPhoneNumberOrBarcode(matchStr, line)) continue;
          if (_isLikelyYearOrDate(cleanedAmount, line)) continue;

          // Hanya ambil nominal yang wajar untuk transaksi (misal: Rp 500 sampai Rp 500.000.000)
          if (cleanedAmount >= 500 && cleanedAmount <= 500000000) {
            candidates.add(cleanedAmount);
          }
        }
      }
    }

    if (candidates.isEmpty) return 0.0;

    // Prioritaskan mencari nominal pada baris yang memiliki kata kunci 'TOTAL' / 'JUMLAH' / 'TAGIHAN'
    double? totalLineAmount;
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('TOTAL') ||
          upper.contains('JUMLAH') ||
          upper.contains('TAGIHAN') ||
          upper.contains('GRAND TOTAL') ||
          upper.contains('BAYAR')) {
        // Jangan ambil baris 'SUBTOTAL' jika ada 'GRAND TOTAL'
        final matches = regex.allMatches(line);
        for (final match in matches) {
          final val = _parseFormattedNumber(match.group(1) ?? '');
          if (val != null && val >= 500 && val <= 500000000) {
            totalLineAmount = max(totalLineAmount ?? 0.0, val);
          }
        }
      }
    }

    // Jika baris bertuliskan TOTAL memiliki angka yang valid, bandingkan dengan angka terbesar
    final largestCandidate = candidates.reduce(max);
    if (totalLineAmount != null && totalLineAmount > 0) {
      // Jika angka terbesar adalah uang tunai bayar (misal bayar 100k, total 85k),
      // totalLineAmount sering kali adalah nominal transaksi yang tepat.
      // Namun aturan spesifik user adalah: "mengekstrak angka terbesar sebagai total nominal",
      // sehingga kita gunakan largestCandidate.
      return max(largestCandidate, totalLineAmount);
    }

    return largestCandidate;
  }

  /// Parsing string angka ke tipe double dengan menangani pemisah ribuan titik/koma
  static double? _parseFormattedNumber(String input) {
    var str = input.replaceAll(' ', '').trim();
    if (str.isEmpty) return null;

    // Jika memiliki format Indonesia "150.000,00" atau internasional "150,000.00"
    if (str.contains('.') && str.contains(',')) {
      final lastDot = str.lastIndexOf('.');
      final lastComma = str.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Format Indonesia: 150.000,50 -> 150000.50
        str = str.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Format Internasional: 150,000.50 -> 150000.50
        str = str.replaceAll(',', '');
      }
    } else if (str.contains('.')) {
      // Cek apakah titik merupakan pemisah desimal atau ribuan
      final parts = str.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        // Format ribuan: 150.000 atau 1.500.000
        str = str.replaceAll('.', '');
      }
    } else if (str.contains(',')) {
      final parts = str.split(',');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        // Format ribuan koma: 150,000
        str = str.replaceAll(',', '');
      } else if (parts.length == 2 && parts[1].length <= 2) {
        // Format desimal: 150,50 -> 150.50
        str = str.replaceAll(',', '.');
      }
    }

    return double.tryParse(str);
  }

  static bool _isLikelyPhoneNumberOrBarcode(String str, String line) {
    final digitsOnly = str.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('08') && digitsOnly.length >= 10) return true;
    if (digitsOnly.length > 12) return true;
    if (line.toUpperCase().contains('TELP') ||
        line.toUpperCase().contains('NO. HP') ||
        line.toUpperCase().contains('NPWP') ||
        line.toUpperCase().contains('BARCODE') ||
        line.toUpperCase().contains('RESI') ||
        line.toUpperCase().contains('KARTU')) {
      return true;
    }
    return false;
  }

  static bool _isLikelyYearOrDate(double value, String line) {
    if (value >= 2020 && value <= 2035) {
      final lower = line.toLowerCase();
      if (lower.contains('/') || lower.contains('-') || lower.contains('tgl') || lower.contains('date')) {
        return true;
      }
    }
    return false;
  }

  /// Ekstrak nama toko / merchant dari bagian atas struk
  static String extractMerchantTitle(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 2)
        .toList();

    for (final line in lines.take(4)) {
      final upper = line.toUpperCase();
      // Lewati header umum struk atau baris tanggal
      if (upper.contains('STRUK') ||
          upper.contains('RECEIPT') ||
          upper.contains('BUKTI') ||
          upper.contains('SELAMAT DATANG') ||
          upper.contains('WELCOME') ||
          upper.contains('TANGGAL') ||
          upper.contains('JAM')) {
        continue;
      }
      return line;
    }

    return 'Transaksi Struk';
  }

  // =====================================================================
  // SMART ITEM EXTRACTION — Parser cerdas untuk mendeteksi item belanjaan
  // =====================================================================

  /// Ekstrak daftar item belanjaan dari teks OCR struk
  /// Mendeteksi pola seperti:
  /// - "Mie Goreng x3  15.000"
  /// - "Mie Goreng   3 pcs  15.000"
  /// - "Mie Goreng   3   15.000"
  /// - "AQUA 600ML   2  @3.000  6.000"
  /// - "1 Nasi Goreng  25000"
  static List<ReceiptItem> extractItems(String rawText) {
    final items = <ReceiptItem>[];
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Kata-kata yang menandakan bukan baris item
    final skipKeywords = [
      'TOTAL', 'SUBTOTAL', 'SUB TOTAL', 'GRAND TOTAL', 'KEMBALIAN',
      'TUNAI', 'CASH', 'CHANGE', 'TAX', 'PPN', 'PAJAK', 'DISKON',
      'DISCOUNT', 'BAYAR', 'TERIMA KASIH', 'THANK', 'STRUK', 'RECEIPT',
      'TANGGAL', 'DATE', 'KASIR', 'CASHIER', 'TELP', 'NO.', 'ALAMAT',
      'ADDRESS', 'MEMBER', 'CARD', 'KARTU', 'NPWP', 'NOTA', 'INVOICE',
      'SELAMAT', 'WELCOME', 'JAM', 'TIME', '====', '----', '****',
      'RESI', 'BARCODE', 'TRANSAKSI',
    ];

    // Regex pola umum item di struk Indonesia
    // Pola 1: "Nama Item  x3  15.000" atau "Nama Item  3  15.000"
    // Pola 2: "3x Nama Item  15.000"  
    // Pola 3: "Nama Item  @5.000  3  15.000"
    // Pola 4: "Nama Item  15.000" (qty=1)
    final priceRegex = RegExp(
      r'(?:Rp\.?\s*)?([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]+)\s*$',
      caseSensitive: false,
    );

    // Deteksi quantity patterns
    final qtyPatterns = [
      // "x3", "X3", "x 3"
      RegExp(r'\bx\s*(\d+)\b', caseSensitive: false),
      // "3 pcs", "3 PCS", "3pcs"
      RegExp(r'\b(\d+)\s*(?:pcs|pc|buah|bh|btl|botol|bks|bungkus|ktk|kotak|lembar|lbr|unit)\b', caseSensitive: false),
      // "3x " at start or middle — "3x Nasi Goreng"
      RegExp(r'\b(\d+)\s*x\s+', caseSensitive: false),
      // "@5.000  3" — harga satuan dan qty
      RegExp(r'@\s*[0-9.,]+\s+(\d+)', caseSensitive: false),
      // Standalone digit between name and price (e.g., "Mie Goreng  3  15.000")
      RegExp(r'\s+(\d{1,3})\s+(?:Rp\.?\s*)?[0-9]{1,3}(?:[.,][0-9]{3})*\s*$', caseSensitive: false),
    ];

    for (final line in lines) {
      final upperLine = line.toUpperCase().trim();

      // Skip header, footer, dan baris non-item
      if (upperLine.length < 4) continue;
      if (skipKeywords.any((kw) => upperLine.contains(kw))) continue;
      // Skip baris yang hanya berisi angka atau separators
      if (RegExp(r'^[=\-*\s.]+$').hasMatch(line)) continue;
      if (RegExp(r'^\d+$').hasMatch(line.trim())) continue;

      // Cari harga di akhir baris
      final priceMatch = priceRegex.firstMatch(line);
      if (priceMatch == null) continue;

      final priceStr = priceMatch.group(1);
      if (priceStr == null) continue;
      final price = _parseFormattedNumber(priceStr);
      if (price == null || price < 100 || price > 100000000) continue;

      // Ambil bagian baris sebelum harga
      String namePart = line.substring(0, priceMatch.start).trim();
      if (namePart.isEmpty) continue;

      // Ekstrak quantity
      int qty = 1;
      bool qtyFound = false;

      for (final qtyPattern in qtyPatterns) {
        final qtyMatch = qtyPattern.firstMatch(namePart);
        if (qtyMatch != null) {
          final parsedQty = int.tryParse(qtyMatch.group(1) ?? '');
          if (parsedQty != null && parsedQty > 0 && parsedQty <= 999) {
            qty = parsedQty;
            // Remove qty pattern from name
            namePart = namePart.replaceFirst(qtyPattern, ' ').trim();
            qtyFound = true;
            break;
          }
        }
      }

      // Juga cek pola "3x NamaBarang" di awal
      if (!qtyFound) {
        final leadingQtyMatch = RegExp(r'^(\d{1,3})\s*x?\s+').firstMatch(namePart);
        if (leadingQtyMatch != null) {
          final parsedQty = int.tryParse(leadingQtyMatch.group(1) ?? '');
          if (parsedQty != null && parsedQty > 0 && parsedQty <= 999) {
            qty = parsedQty;
            namePart = namePart.substring(leadingQtyMatch.end).trim();
          }
        }
      }

      // Bersihkan harga satuan "@5.000" dari nama jika masih ada
      namePart = namePart.replaceAll(RegExp(r'@\s*[0-9.,]+'), '').trim();
      // Bersihkan karakter noise
      namePart = namePart.replaceAll(RegExp(r'^[\s\-*.:]+|[\s\-*.:]+$'), '').trim();

      if (namePart.isEmpty || namePart.length < 2) continue;

      // Hitung harga satuan
      final unitPrice = qty > 1 ? (price / qty) : price;

      items.add(ReceiptItem(
        name: _capitalizeItemName(namePart),
        qty: qty,
        unitPrice: unitPrice.roundToDouble(),
      ));
    }

    return items;
  }

  /// Capitalize nama item agar lebih rapi
  static String _capitalizeItemName(String name) {
    if (name.isEmpty) return name;
    // Jika semua huruf kapital, ubah ke title case
    if (name == name.toUpperCase() && name.length > 3) {
      return name.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }
    // Jika sudah mixed case, biarkan apa adanya tapi capitalize huruf pertama
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Kamus kata kunci untuk pencocokan kategori umum
  static final Map<String, List<String>> categoryKeywords = {
    'Makanan & Minuman': [
      'kopi', 'coffee', 'cafe', 'kafe', 'resto', 'restoran', 'warung', 'rumah makan',
      'nasi', 'ayam', 'mie', 'bakso', 'soto', 'burger', 'pizza', 'roti', 'bakery',
      'dapur', 'minuman', 'makanan', 'snack', 'jus', 'tea', 'teh', 'boba', 'mcdonald',
      'kfc', 'starbucks', 'kenangan', 'janji jiwa'
    ],
    'Belanja': [
      'indomaret', 'alfamart', 'supermarket', 'hypermart', 'transmart', 'superindo',
      'minimarket', 'toko', 'mart', 'pasar', 'mall', 'shopee', 'tokopedia', 'lazada',
      'fashion', 'baju', 'pakaian', 'celana', 'sepatu', 'tas'
    ],
    'Transportasi': [
      'spbu', 'pertamina', 'shell', 'bp', 'bensin', 'pertalite', 'pertamax', 'solar',
      'ojek', 'gojek', 'gocar', 'goride', 'grab', 'maxim', 'parkir', 'tol',
      'kereta', 'krl', 'mrt', 'lrt', 'transjakarta', 'taksi', 'taxi'
    ],
    'Tagihan & Utilitas': [
      'pln', 'listrik', 'token', 'pdam', 'air', 'wifi', 'indihome', 'biznet',
      'telkomsel', 'indosat', 'xl', 'pulsa', 'kuota', 'bpjs', 'pajak', 'iuran'
    ],
    'Kesehatan': [
      'apotek', 'farmasi', 'klinik', 'obat', 'dokter', 'kimia farma', 'k24', 'century',
      'guardian', 'watsons', 'rumah sakit', 'rsud', 'laboratorium', 'vitamin'
    ],
    'Hiburan': [
      'cinema', 'xxi', 'cgv', 'cinepolis', 'bioskop', 'tiket', 'karaoke',
      'game', 'steam', 'playstation', 'wisata', 'taman', 'rekreasi', 'billiard'
    ],
    'Pendidikan': [
      'buku', 'gramedia', 'alat tulis', 'atk', 'fotocopy', 'les', 'kursus', 'sekolah', 'kampus'
    ],
  };

  /// Mencocokkan teks struk dengan kategori yang ada,
  /// atau membuat kategori baru secara otomatis jika diaktifkan.
  static Future<({CategoryModel category, bool isNewCreated})> matchOrSuggestCategory({
    required String rawText,
    required List<CategoryModel> existingCategories,
    CategoryProvider? categoryProvider,
    bool autoCreateIfNotFound = true,
  }) async {
    final lowerText = rawText.toLowerCase();

    // 1. Cek apakah ada nama kategori yang persis terdapat di dalam teks struk
    for (final cat in existingCategories) {
      final catNameLower = cat.name.toLowerCase();
      if (catNameLower.length > 3 && lowerText.contains(catNameLower)) {
        return (category: cat, isNewCreated: false);
      }
    }

    // 2. Cocokkan kata kunci kamus dengan kategori yang ada
    for (final entry in categoryKeywords.entries) {
      final targetCategoryName = entry.key;
      final keywords = entry.value;

      final hasMatch = keywords.any((kw) => lowerText.contains(kw.toLowerCase()));
      if (hasMatch) {
        // Cari apakah target category sudah ada di existingCategories
        final matchedCategory = existingCategories.firstWhere(
          (c) => c.name.toLowerCase().contains(targetCategoryName.toLowerCase()) ||
              targetCategoryName.toLowerCase().contains(c.name.toLowerCase()),
          orElse: () => const CategoryModel(id: '', name: '', icon: '', type: TransactionType.expense),
        );

        if (matchedCategory.id.isNotEmpty) {
          return (category: matchedCategory, isNewCreated: false);
        }

        // Jika belum ada di list dan autoCreate diizinkan, buat kategori baru otomatis
        if (autoCreateIfNotFound && categoryProvider != null) {
          final icon = _suggestIconForCategory(targetCategoryName);
          final success = await categoryProvider.addCategory(
            name: targetCategoryName,
            icon: icon,
            type: TransactionType.expense,
          );
          if (success) {
            final newCat = categoryProvider.categories.firstWhere(
              (c) => c.name == targetCategoryName,
            );
            return (category: newCat, isNewCreated: true);
          }
        }
      }
    }

    // 3. Jika struk memiliki merchant khusus (misal: Laundry, Toko Hewan, Bengkel)
    if (autoCreateIfNotFound && categoryProvider != null) {
      if (lowerText.contains('laundry') || lowerText.contains('cuci')) {
        const catName = 'Laundry & Cuci';
        await categoryProvider.addCategory(
          name: catName,
          icon: 'local_laundry_service',
          type: TransactionType.expense,
        );
        final created = categoryProvider.categories.firstWhere((c) => c.name == catName);
        return (category: created, isNewCreated: true);
      }

      if (lowerText.contains('bengkel') || lowerText.contains('service') || lowerText.contains('oli')) {
        const catName = 'Perawatan Kendaraan';
        await categoryProvider.addCategory(
          name: catName,
          icon: 'directions_car',
          type: TransactionType.expense,
        );
        final created = categoryProvider.categories.firstWhere((c) => c.name == catName);
        return (category: created, isNewCreated: true);
      }
    }

    // 4. Fallback jika kategori tidak ditemukan: gunakan kategori default 'Lainnya' atau kategori pertama
    final defaultExpense = existingCategories.firstWhere(
      (c) => c.type == TransactionType.expense && c.name.toLowerCase().contains('lain'),
      orElse: () => existingCategories.firstWhere(
        (c) => c.type == TransactionType.expense,
        orElse: () => existingCategories.isNotEmpty
            ? existingCategories.first
            : const CategoryModel(
                id: 'default_expense',
                name: 'Pengeluaran Umum',
                icon: 'more_horiz',
                type: TransactionType.expense,
              ),
      ),
    );

    return (category: defaultExpense, isNewCreated: false);
  }

  static String _suggestIconForCategory(String categoryName) {
    switch (categoryName) {
      case 'Makanan & Minuman':
        return 'fastfood';
      case 'Belanja':
        return 'shopping_bag';
      case 'Transportasi':
        return 'directions_car';
      case 'Tagihan & Utilitas':
        return 'receipt_long';
      case 'Kesehatan':
        return 'medical_services';
      case 'Hiburan':
        return 'movie';
      case 'Pendidikan':
        return 'school';
      default:
        return 'category';
    }
  }
}
