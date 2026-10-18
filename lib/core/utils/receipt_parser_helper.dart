import 'dart:math';

import '../../data/models/category_model.dart';
import '../../data/models/receipt_item_model.dart';
import '../../data/models/transaction_type.dart';
import '../../logic/providers/category_provider.dart';

class ReceiptParserHelper {
  static const List<String> _totalPriorityKeywords = [
    'GRAND TOTAL',
    'TOTAL AKHIR',
    'TOTAL BAYAR',
    'TOTAL',
    'GOPAY',
    'QRIS',
    'TUNAI',
  ];

  static final Set<String> _headerBlacklist = {
    'CETAK',
    'ULANG',
    'NO',
    'NOMOR',
    'NOTA',
    'TANGGAL',
    'JAM',
    'INFO',
    'MODE',
    'KASIR',
    'THANK YOU',
    'TERIMA KASIH',
    'KELUHAN',
    'GOPAY',
    'SUBTOTAL',
    'GRAND TOTAL',
    'TOTAL',
    'BAYAR',
    'TUNAI',
    'KEMBALIAN',
    'PEMBAYARAN',
    'MACHINE',
    'CASHIER',
    'DATE',
    'TIME',
    'ADDRESS',
    'ALAMAT',
    'TELP',
    'PHONE',
    'BARCODE',
    'RESI',
    'MEMBER',
    'CARD',
    'NPWP',
    'CASH',
    'CHANGE',
    'TAKE AWAY',
    'DINE IN',
  };

  static bool _containsHeaderKeyword(String line) {
    final upper = line.trim().toUpperCase();
    if (upper.isEmpty) return true;
    return _headerBlacklist.any((keyword) => upper.contains(keyword));
  }

  static bool _isReceiptSeparatorLine(String line) {
    final trimmed = line.trim();
    return trimmed.isEmpty ||
        RegExp(r'^[=\-*#_./\\|\s]+$').hasMatch(trimmed) ||
        RegExp(r'^(?:\d{1,3}\s*X\s*)?(?:[A-Z0-9]+\s*){1,4}$')
                .hasMatch(trimmed) &&
            !trimmed.contains(RegExp(r'[A-Za-z]'));
  }

  static bool _isLikelyDateTimeLine(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('TANGGAL') ||
        upper.contains('DATE') ||
        upper.contains('JAM') ||
        upper.contains('TIME')) {
      return true;
    }
    return RegExp(r'\d{1,2}[/:\-]\d{1,2}([/:\-]\d{2,4})?').hasMatch(line);
  }

  static bool _isSubTotalLikeLine(String line) {
    final upper = line.toUpperCase();
    return upper.contains('SUBTOTAL') || upper.contains('SUB TOTAL');
  }

  static List<String> _normalizeLines(String rawText) {
    final lines = rawText.split(RegExp(r'\r?\n'));
    final normalized = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) normalized.add(trimmed);
    }
    return normalized;
  }

  static double? _extractAmountFromLine(String line) {
    final regex = RegExp(
      r'(?:Rp\.?|IDR)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]+)',
      caseSensitive: false,
    );

    double? result;
    for (final match in regex.allMatches(line)) {
      final value = _parseFormattedNumber(match.group(1) ?? '');
      if (value != null && value >= 500 && value <= 500000000) {
        result = value;
      }
    }
    return result;
  }

  /// Ekstrak angka terbesar dari teks struk sebagai total nominal
  static double extractLargestAmount(String rawText) {
    if (rawText.trim().isEmpty) return 0.0;

    final totalByRule = extractTotalAmount(rawText);
    if (totalByRule > 0) return totalByRule;

    final candidates = <double>[];
    final lines = rawText.split('\n');

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
          if (_isLikelyPhoneNumberOrBarcode(matchStr, line)) continue;
          if (_isLikelyYearOrDate(cleanedAmount, line)) continue;

          if (cleanedAmount >= 500 && cleanedAmount <= 500000000) {
            candidates.add(cleanedAmount);
          }
        }
      }
    }

    if (candidates.isEmpty) return 0.0;

    double? totalLineAmount;
    for (final line in lines) {
      final upper = line.toUpperCase();
      if (upper.contains('SUBTOTAL') || upper.contains('SUB TOTAL')) {
        continue;
      }
      if (upper.contains('TOTAL') ||
          upper.contains('JUMLAH') ||
          upper.contains('TAGIHAN') ||
          upper.contains('GRAND TOTAL') ||
          upper.contains('BAYAR')) {
        final matches = regex.allMatches(line);
        for (final match in matches) {
          final val = _parseFormattedNumber(match.group(1) ?? '');
          if (val != null && val >= 500 && val <= 500000000) {
            totalLineAmount = max(totalLineAmount ?? 0.0, val);
          }
        }
      }
    }

    final largestCandidate = candidates.reduce(max);
    if (totalLineAmount != null && totalLineAmount > 0) {
      return max(largestCandidate, totalLineAmount);
    }

    return largestCandidate;
  }

  static double extractTotalAmount(String rawText) {
    if (rawText.trim().isEmpty) return 0.0;

    final lines = _normalizeLines(rawText);
    if (lines.isEmpty) return 0.0;

    for (final keyword in _totalPriorityKeywords) {
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final upper = line.toUpperCase();

        if (_isSubTotalLikeLine(line)) continue;
        if (!upper.contains(keyword)) continue;
        if (upper.contains('KEMBALIAN') ||
            upper.contains('CASH') ||
            upper.contains('CHANGE')) {
          continue;
        }

        final directAmount = _extractAmountFromLine(line);
        if (directAmount != null) {
          return directAmount;
        }

        for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
          final nearby = _extractAmountFromLine(lines[j]);
          if (nearby != null) {
            return nearby;
          }
        }
      }
    }

    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final upper = line.toUpperCase();
      if (_isSubTotalLikeLine(line)) continue;
      if (upper.contains('TOTAL') ||
          upper.contains('JUMLAH') ||
          upper.contains('TAGIHAN')) {
        final amount = _extractAmountFromLine(line);
        if (amount != null) return amount;
        for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
          final nearby = _extractAmountFromLine(lines[j]);
          if (nearby != null) return nearby;
        }
      }
    }

    return 0.0;
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
      if (lower.contains('/') ||
          lower.contains('-') ||
          lower.contains('tgl') ||
          lower.contains('date')) {
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
  static List<ReceiptItem> extractItems(String rawText) {
    final items = <ReceiptItem>[];
    final lines = _normalizeLines(rawText);

    final priceRegex = RegExp(
      r'(?:Rp\.?\s*)?([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})?|[0-9]+)\s*$',
      caseSensitive: false,
    );

    final qtyPatterns = [
      RegExp(r'\b(\d+)\s*x\b', caseSensitive: false),
      RegExp(r'\bx\s*(\d+)\b', caseSensitive: false),
      RegExp(
        r'\b(\d+)\s*(?:pcs|pc|buah|bh|btl|botol|bks|bungkus|ktk|unit|pack)\b',
        caseSensitive: false,
      ),
      RegExp(r'@\s*[0-9.,]+\s+(\d+)\b', caseSensitive: false),
      RegExp(
        r'\s+(\d{1,3})\s+(?:Rp\.?\s*)?[0-9]{1,3}(?:[.,][0-9]{3})*\s*$',
        caseSensitive: false,
      ),
      RegExp(r'^(\d{1,3})\s*(?:x|\s+)', caseSensitive: false),
    ];

    for (final line in lines) {
      final upperLine = line.toUpperCase();
      if (upperLine.length < 4) continue;
      if (_containsHeaderKeyword(line)) continue;
      if (_isReceiptSeparatorLine(line)) continue;
      if (_isLikelyDateTimeLine(line)) continue;
      if (upperLine.contains('TOTAL') ||
          upperLine.contains('SUBTOTAL') ||
          upperLine.contains('GRAND TOTAL') ||
          upperLine.contains('KEMBALIAN') ||
          upperLine.contains('THANK YOU') ||
          upperLine.contains('TERIMA KASIH')) {
        continue;
      }
      if (RegExp(r'^[0-9]+$').hasMatch(line)) continue;

      final hasQuantitySignal = RegExp(
        r'(?:\d+\s*x|x\s*\d+|@\s*\d|\d+\s*(?:pcs|pc|buah|bh|btl|botol|ktk|pack))',
        caseSensitive: false,
      ).hasMatch(line);
      if (!hasQuantitySignal) continue;

      final priceMatch = priceRegex.firstMatch(line);
      if (priceMatch == null) continue;

      final priceStr = priceMatch.group(1);
      if (priceStr == null) continue;
      final price = _parseFormattedNumber(priceStr);
      if (price == null || price < 100 || price > 100000000) continue;

      String namePart = line.substring(0, priceMatch.start).trim();
      if (namePart.isEmpty) continue;

      int qty = 1;
      for (final qtyPattern in qtyPatterns) {
        final qtyMatch = qtyPattern.firstMatch(namePart);
        if (qtyMatch == null) continue;

        final parsedQty = int.tryParse(qtyMatch.group(1) ?? '');
        if (parsedQty != null && parsedQty > 0 && parsedQty <= 999) {
          qty = parsedQty;
          namePart = namePart.replaceFirst(qtyPattern, ' ').trim();
          break;
        }
      }

      namePart = namePart
          .replaceAll(RegExp(r'@\s*[0-9.,]+'), '')
          .replaceAll(RegExp(r'\b(?:rp|idr)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ&/()\-\s.,]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      namePart = namePart
          .replaceAll(RegExp(r'^[\-.*:;,_]+|[\-.*:;,_]+$'), '')
          .trim();
      if (namePart.isEmpty || namePart.length < 2) continue;

      final item = ReceiptItem(
        name: _capitalizeItemName(namePart),
        qty: qty,
        unitPrice: (qty > 1 ? price / qty : price).roundToDouble(),
      );

      if (!items.any(
        (existing) =>
            existing.name.toLowerCase() == item.name.toLowerCase() &&
            existing.qty == item.qty,
      )) {
        items.add(item);
      }
    }

    return items;
  }

  /// Capitalize nama item agar lebih rapi
  static String _capitalizeItemName(String name) {
    if (name.isEmpty) return name;
    // Jika semua huruf kapital, ubah ke title case
    if (name == name.toUpperCase() && name.length > 3) {
      return name
          .split(' ')
          .map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');
    }
    // Jika sudah mixed case, biarkan apa adanya tapi capitalize huruf pertama
    return name[0].toUpperCase() + name.substring(1);
  }

  /// Kamus kata kunci untuk pencocokan kategori umum
  static final Map<String, List<String>> categoryKeywords = {
    'Makanan & Minuman': [
      'kopi',
      'coffee',
      'cafe',
      'kafe',
      'resto',
      'restoran',
      'warung',
      'rumah makan',
      'nasi',
      'ayam',
      'mie',
      'bakso',
      'soto',
      'burger',
      'pizza',
      'roti',
      'bakery',
      'dapur',
      'minuman',
      'makanan',
      'snack',
      'jus',
      'tea',
      'teh',
      'boba',
      'mcdonald',
      'kfc',
      'starbucks',
      'kenangan',
      'janji jiwa',
    ],
    'Belanja': [
      'indomaret',
      'alfamart',
      'supermarket',
      'hypermart',
      'transmart',
      'superindo',
      'minimarket',
      'toko',
      'mart',
      'pasar',
      'mall',
      'shopee',
      'tokopedia',
      'lazada',
      'fashion',
      'baju',
      'pakaian',
      'celana',
      'sepatu',
      'tas',
    ],
    'Transportasi': [
      'spbu',
      'pertamina',
      'shell',
      'bp',
      'bensin',
      'pertalite',
      'pertamax',
      'solar',
      'ojek',
      'gojek',
      'gocar',
      'goride',
      'grab',
      'maxim',
      'parkir',
      'tol',
      'kereta',
      'krl',
      'mrt',
      'lrt',
      'transjakarta',
      'taksi',
      'taxi',
    ],
    'Tagihan & Utilitas': [
      'pln',
      'listrik',
      'token',
      'pdam',
      'air',
      'wifi',
      'indihome',
      'biznet',
      'telkomsel',
      'indosat',
      'xl',
      'pulsa',
      'kuota',
      'bpjs',
      'pajak',
      'iuran',
    ],
    'Kesehatan': [
      'apotek',
      'farmasi',
      'klinik',
      'obat',
      'dokter',
      'kimia farma',
      'k24',
      'century',
      'guardian',
      'watsons',
      'rumah sakit',
      'rsud',
      'laboratorium',
      'vitamin',
    ],
    'Hiburan': [
      'cinema',
      'xxi',
      'cgv',
      'cinepolis',
      'bioskop',
      'tiket',
      'karaoke',
      'game',
      'steam',
      'playstation',
      'wisata',
      'taman',
      'rekreasi',
      'billiard',
    ],
    'Pendidikan': [
      'buku',
      'gramedia',
      'alat tulis',
      'atk',
      'fotocopy',
      'les',
      'kursus',
      'sekolah',
      'kampus',
    ],
  };

  /// Mencocokkan teks struk dengan kategori yang ada,
  /// atau membuat kategori baru secara otomatis jika diaktifkan.
  static Future<({CategoryModel category, bool isNewCreated})>
  matchOrSuggestCategory({
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

      final hasMatch = keywords.any(
        (kw) => lowerText.contains(kw.toLowerCase()),
      );
      if (hasMatch) {
        // Cari apakah target category sudah ada di existingCategories
        final matchedCategory = existingCategories.firstWhere(
          (c) =>
              c.name.toLowerCase().contains(targetCategoryName.toLowerCase()) ||
              targetCategoryName.toLowerCase().contains(c.name.toLowerCase()),
          orElse: () => const CategoryModel(
            id: '',
            name: '',
            icon: '',
            type: TransactionType.expense,
          ),
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
        final created = categoryProvider.categories.firstWhere(
          (c) => c.name == catName,
        );
        return (category: created, isNewCreated: true);
      }

      if (lowerText.contains('bengkel') ||
          lowerText.contains('service') ||
          lowerText.contains('oli')) {
        const catName = 'Perawatan Kendaraan';
        await categoryProvider.addCategory(
          name: catName,
          icon: 'directions_car',
          type: TransactionType.expense,
        );
        final created = categoryProvider.categories.firstWhere(
          (c) => c.name == catName,
        );
        return (category: created, isNewCreated: true);
      }
    }

    // 4. Fallback jika kategori tidak ditemukan: gunakan kategori default 'Lainnya' atau kategori pertama
    final defaultExpense = existingCategories.firstWhere(
      (c) =>
          c.type == TransactionType.expense &&
          c.name.toLowerCase().contains('lain'),
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
