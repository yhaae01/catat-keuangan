import 'dart:math';

import '../../data/models/category_model.dart';
import '../../data/models/receipt_item_model.dart';
import '../../data/models/transaction_type.dart';
import '../../logic/providers/category_provider.dart';

class ReceiptParserHelper {
  // =====================================================================
  // 1. POLA KATA KUNCI HEADER, FOOTER & METADATA UNIVERSAL
  // =====================================================================

  /// Daftar pola regex untuk mendeteksi baris header, footer, atau metadata
  /// yang harus diabaikan saat scanning item struk belanja.
  static final List<RegExp> _headerFooterPatterns = [
    // Header cetak ulang / reprint
    RegExp(r'\b(?:CETAK\s*ULANG|REPRINT|COPY|DUPLICATE)\b', caseSensitive: false),
    // Kasir / Staff
    RegExp(r'\b(?:KASIR|CASHIER|OPERATOR|PELAYAN|SERVER|STAFF)\b', caseSensitive: false),
    // Waktu & Tanggal
    RegExp(r'\b(?:TANGGAL|DATE|TGL|JAM|WAKTU|TIME)\b', caseSensitive: false),
    // Nomor nota / transaksi / invoice
    RegExp(
      r'\b(?:NO(?:\.|\s*:|\b)|NOMOR|NOTA|INVOICE|RESI|RECEIPT|STRUK|ORDER\s*#|BILL(?:\s*#|\b))\b',
      caseSensitive: false,
    ),
    // Kalimat penutup / salam
    RegExp(
      r'\b(?:TERIMA\s*KASIH|THANK\s*YOU|SELAMAT\s*DATANG|WELCOME|SEE\s*YOU|VISIT\s*AGAIN)\b',
      caseSensitive: false,
    ),
    // Subtotal & Pajak
    RegExp(r'\b(?:SUBTOTAL|SUB\s*TOTAL|SUB-TOTAL)\b', caseSensitive: false),
    RegExp(
      r'\b(?:PPN|PB1|PB\s*1|TAX|PAJAK|SERVICE\s*CHARGE|SVC|DISKON|DISCOUNT|HEMAT|PROMO)\b',
      caseSensitive: false,
    ),
    // Kata kunci Total (diproses terpisah di ekstraksi total)
    RegExp(
      r'\b(?:GRAND\s*TOTAL|TOTAL\s*BAYAR|TOTAL\s*AKHIR|TOTAL\s*TAGIHAN|JUMLAH\s*TOTAL|JUMLAH\s*BAYAR|TOTAL|JUMLAH)\b',
      caseSensitive: false,
    ),
    // Metode pembayaran & kembalian
    RegExp(
      r'\b(?:TUNAI|CASH|KEMBALI|KEMBALIAN|CHANGE|DEBIT|KREDIT|EDC|QRIS|GOPAY|OVO|DANA|SHOPEEPAY|LINKAJA)\b',
      caseSensitive: false,
    ),
    // Informasi kontak & legalitas
    RegExp(
      r'\b(?:TELP|TELEPON|PHONE|NO\.\s*HP|ALAMAT|ADDRESS|NPWP|BARCODE|WIFI|PASSWORD|PASSWD)\b',
      caseSensitive: false,
    ),
    // Mode makan / meja
    RegExp(
      r'\b(?:TAKE\s*AWAY|DINE\s*IN|BUNGKUS|NO\s*MEJA|TABLE\s*NO|TABLE)\b',
      caseSensitive: false,
    ),
  ];

  /// Kata kunci prioritas tertinggi untuk menemukan Grand Total
  static const List<String> _totalPriorityKeywords = [
    'GRAND TOTAL',
    'TOTAL BAYAR',
    'TOTAL AKHIR',
    'TOTAL TAGIHAN',
    'JUMLAH TOTAL',
    'JUMLAH BAYAR',
    'TOTAL',
    'JUMLAH',
    'TAGIHAN',
  ];

  // =====================================================================
  // 2. REGEX POLA HARGA & KUANTITAS (PATTERN MATCHING)
  // =====================================================================

  /// Regex untuk mendeteksi angka harga dengan pemisah ribuan titik/koma
  /// Mengabaikan angka volume/berat produk seperti "600ml", "500gr", dll.
  static final RegExp priceRegex = RegExp(
    r'(?:(?:Rp\.?|IDR|@)\s*)?([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{2})?|[0-9]{4,}(?:[.,][0-9]{2})?|(?:(?<=Rp\.?|IDR|@)\s*)[0-9]{3,})\b(?!\s*(?:ml|l|liter|g|gram|gr|kg|cm|mm|oz|v|w)\b)',
    caseSensitive: false,
  );

  /// Pola-pola kuantitas fleksibel ("1x", "2 x", "x3", "2 pcs", "@15.000 2", angka di depan nama)
  static final List<RegExp> _qtyPatterns = [
    // "1x", "2 x", "3X" di awal atau dalam baris
    RegExp(r'\b(\d{1,3})\s*[xX]\b', caseSensitive: false),
    // "x1", "x 2", "X3"
    RegExp(r'\b[xX]\s*(\d{1,3})\b', caseSensitive: false),
    // Satuan kuantitas umum: pcs, pc, buah, bh, btl, botol, bks, bungkus, ktk, kotak, unit, porsi, cup, can, pack, kaleng, butir, kg, gram, dll.
    RegExp(
      r'\b(\d{1,3})\s*(?:pcs|pc|buah|bh|btl|botol|bks|bungkus|ktk|kotak|unit|porsi|cup|can|pack|kaleng|butir|piring|gelas|slice|kg|gram|gr|ons|ltr|liter)\b',
      caseSensitive: false,
    ),
    // Format "@ harga kuantitas" misal: @15.000 2
    RegExp(r'@\s*[0-9.,]+\s+(\d{1,3})\b', caseSensitive: false),
    // Format "kuantitas @ harga" misal: 2 @ 15.000
    RegExp(r'\b(\d{1,3})\s*@\s*[0-9.,]+', caseSensitive: false),
    // Angka di awal baris yang diikuti nama item (misal "2 Kopi Kenangan", bukan tahun/kode produk)
    RegExp(r'^(\d{1,2})\s+(?=[A-Za-z])', caseSensitive: false),
  ];

  // =====================================================================
  // 3. FUNGSI PEMBERSIH & VALIDATOR TEKS
  // =====================================================================

  /// Mengecek apakah baris teks merupakan header, footer, pemisah, atau metadata
  static bool isUniversalHeaderOrFooter(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    if (isReceiptSeparatorLine(trimmed)) return true;
    if (_isLikelyDateTimeLine(trimmed)) return true;

    for (final pattern in _headerFooterPatterns) {
      if (pattern.hasMatch(trimmed)) {
        return true;
      }
    }

    return false;
  }

  /// Mengecek apakah baris hanya berupa garis pemisah (seperti ===, ---, ***, dll.)
  static bool isReceiptSeparatorLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(r'^[=\-*#_./\\|\s]+$').hasMatch(trimmed);
  }

  /// Mengecek apakah baris teks didominasi oleh waktu/tanggal
  static bool _isLikelyDateTimeLine(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('TANGGAL') ||
        upper.contains('DATE') ||
        upper.contains('JAM') ||
        upper.contains('TIME')) {
      return true;
    }
    final trimmed = line.trim();
    // Waktu seperti 14:32 atau 14:32:00
    if (RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?\b').hasMatch(trimmed)) {
      return true;
    }
    // Tanggal seperti 18/10/2026 atau 18-10-2026
    if (RegExp(r'^\d{1,2}[/\-]\d{1,2}([/\-]\d{2,4})?\b').hasMatch(trimmed)) {
      return true;
    }
    // Tanggal dengan titik (harus ada hari, bulan, dan tahun): 18.10.2026
    if (RegExp(r'^\d{1,2}\.\d{1,2}\.\d{2,4}\b').hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  /// Normalisasi teks struk menjadi list baris yang bersih dari baris kosong
  static List<String> normalizeLines(String rawText) {
    final lines = rawText.split(RegExp(r'\r?\n'));
    final normalized = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        normalized.add(trimmed);
      }
    }
    return normalized;
  }

  /// Parsing string angka ke tipe double (mendukung pemisah ribuan titik/koma)
  static double? parseFormattedNumber(String input) {
    var str = input.replaceAll(' ', '').trim();
    if (str.isEmpty) return null;

    // Bersihkan prefix mata uang
    str = str.replaceAll(RegExp(r'^(?:Rp\.?|IDR)', caseSensitive: false), '');

    // Format Indonesia: 150.000,50 atau Internasional: 150,000.50
    if (str.contains('.') && str.contains(',')) {
      final lastDot = str.lastIndexOf('.');
      final lastComma = str.lastIndexOf(',');
      if (lastComma > lastDot) {
        // Format Indonesia (titik ribuan, koma desimal)
        str = str.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Format Internasional (koma ribuan, titik desimal)
        str = str.replaceAll(',', '');
      }
    } else if (str.contains('.')) {
      final parts = str.split('.');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        // Titik sebagai pemisah ribuan (e.g. 35.000 atau 1.500.000)
        str = str.replaceAll('.', '');
      } else if (parts.length == 2 && parts[1].length <= 2) {
        // Titik sebagai desimal (e.g. 35.50)
      }
    } else if (str.contains(',')) {
      final parts = str.split(',');
      if (parts.length > 2 || (parts.length == 2 && parts[1].length == 3)) {
        // Koma sebagai pemisah ribuan (e.g. 35,000)
        str = str.replaceAll(',', '');
      } else if (parts.length == 2 && parts[1].length <= 2) {
        // Koma sebagai desimal (e.g. 35,50)
        str = str.replaceAll(',', '.');
      }
    }

    return double.tryParse(str);
  }

  // =====================================================================
  // 4. ALGORITMA EKSTRAKSI GRAND TOTAL UNIVERSAL
  // =====================================================================

  /// Mengekstrak angka total akhir (Grand Total) universal dari struk
  /// Mengabaikan 'Subtotal' dan mengutamakan kata kunci total terkuat.
  static double extractTotalAmount(String rawText) {
    if (rawText.trim().isEmpty) return 0.0;
    final lines = normalizeLines(rawText);
    if (lines.isEmpty) return 0.0;

    // Targeted Regex untuk menangkap angka yang berada tepat setelah kata kunci Total
    // Menghindari tertukar dengan angka Tunai/Kembalian jika dalam 1 baris
    final targetedTotalRegex = RegExp(
      r'(?:GRAND\s*TOTAL|TOTAL\s*BAYAR|TOTAL\s*AKHIR|TOTAL\s*TAGIHAN|JUMLAH\s*TOTAL|JUMLAH\s*BAYAR|TOTAL|JUMLAH)\s*[:=]?\s*(?:Rp\.?|IDR)?\s*([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{2})?|[0-9]{4,}(?:[.,][0-9]{2})?|[0-9]{3,})',
      caseSensitive: false,
    );

    // Langkah 1: Cari berdasarkan urutan prioritas kata kunci terkuat
    for (final keyword in _totalPriorityKeywords) {
      for (var i = lines.length - 1; i >= 0; i--) {
        final line = lines[i];
        final upper = line.toUpperCase();

        // Abaikan jika baris merupakan Subtotal
        if (upper.contains('SUBTOTAL') || upper.contains('SUB TOTAL') || upper.contains('SUB-TOTAL')) {
          continue;
        }

        // Cek apakah baris mengandung kata kunci saat ini
        if (!upper.contains(keyword)) continue;

        // Coba ekstrak nominal yang langsung mengikuti kata kunci
        final directMatch = targetedTotalRegex.firstMatch(line);
        if (directMatch != null) {
          final val = parseFormattedNumber(directMatch.group(1) ?? '');
          if (val != null && val >= 500 && val <= 500000000) {
            return val;
          }
        }

        // Ekstrak nominal harga umum dari baris tersebut (jika tidak ada kata kunci Tunai/Kembali)
        if (!upper.contains('KEMBALI') && !upper.contains('CHANGE')) {
          final lineAmount = _extractLastPriceFromLine(line);
          if (lineAmount != null) {
            return lineAmount;
          }
        }

        // Jika keyword berada di baris sendiri (misal "GRAND TOTAL" lalu baris berikutnya "38.000")
        for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
          final nextUpper = lines[j].toUpperCase();
          if (nextUpper.contains('KEMBALI') || nextUpper.contains('CHANGE')) {
            continue;
          }
          final nearbyAmount = _extractLastPriceFromLine(lines[j]);
          if (nearbyAmount != null) {
            return nearbyAmount;
          }
        }
      }
    }

    // Langkah 2: Fallback scanning baris dari bawah ke atas mencari baris berisi TOTAL
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      final upper = line.toUpperCase();
      if (upper.contains('SUBTOTAL') || upper.contains('SUB TOTAL')) continue;

      if (upper.contains('TOTAL') || upper.contains('JUMLAH') || upper.contains('TAGIHAN')) {
        final amount = _extractLastPriceFromLine(line);
        if (amount != null) return amount;

        for (var j = i + 1; j < lines.length && j <= i + 2; j++) {
          final nearby = _extractLastPriceFromLine(lines[j]);
          if (nearby != null) return nearby;
        }
      }
    }

    return 0.0;
  }

  /// Ekstraksi nominal harga terbesar / paling relevan dari teks struk
  static double extractLargestAmount(String rawText) {
    if (rawText.trim().isEmpty) return 0.0;

    // 1. Cek dulu menggunakan algoritma Grand Total Universal
    final totalByRule = extractTotalAmount(rawText);
    if (totalByRule > 0) return totalByRule;

    // 2. Kumpulkan semua kandidat nominal yang valid
    final lines = normalizeLines(rawText);
    final candidates = <double>[];

    for (final line in lines) {
      final matches = priceRegex.allMatches(line);
      for (final match in matches) {
        final matchStr = match.group(1);
        if (matchStr == null) continue;

        final cleanedAmount = parseFormattedNumber(matchStr);
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

    // 3. Ambil nominal terbesar
    return candidates.reduce(max);
  }

  static double? _extractLastPriceFromLine(String line) {
    final matches = priceRegex.allMatches(line).toList();
    if (matches.isEmpty) return null;

    // Ambil harga yang paling kanan pada baris (karena harga baris umumnya di sisi kanan)
    for (var i = matches.length - 1; i >= 0; i--) {
      final str = matches[i].group(1);
      if (str == null) continue;

      if (_isLikelyPhoneNumberOrBarcode(str, line)) continue;
      final val = parseFormattedNumber(str);
      if (val != null && val >= 500 && val <= 500000000) {
        if (!_isLikelyYearOrDate(val, line)) {
          return val;
        }
      }
    }
    return null;
  }

  static bool _isLikelyPhoneNumberOrBarcode(String str, String line) {
    final digitsOnly = str.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.startsWith('08') && digitsOnly.length >= 10) return true;
    if (digitsOnly.length > 12) return true;
    final upper = line.toUpperCase();
    if (upper.contains('TELP') ||
        upper.contains('NO. HP') ||
        upper.contains('NPWP') ||
        upper.contains('BARCODE') ||
        upper.contains('RESI') ||
        upper.contains('KARTU')) {
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

  // =====================================================================
  // 5. PEMISAHAN BLOK & EKSTRAKSI ITEM BELANJAAN BEBAS POSISI
  // =====================================================================

  /// Ekstrak daftar item belanjaan secara dinamis dan fleksibel untuk berbagai format struk
  static List<ReceiptItem> extractItems(String rawText) {
    final items = <ReceiptItem>[];
    final lines = normalizeLines(rawText);

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // Abaikan header, footer, garis pemisah, dan baris non-item universal
      if (isUniversalHeaderOrFooter(line)) {
        i++;
        continue;
      }

      // ── FORMAT 1: Single-Line Item (Nama, Qty, dan Harga berada dalam 1 baris) ──
      final singleLineItem = _tryParseSingleLineItem(line);
      if (singleLineItem != null) {
        _addItemIfNotExists(items, singleLineItem);
        i++;
        continue;
      }

      // ── FORMAT 2: Multi-Line Item (Nama di baris i, Qty & Harga di baris i+1 / i+2) ──
      // Cek apakah baris i adalah teks nama item (memiliki huruf, bukan angka saja)
      if (_isPlausibleItemName(line)) {
        ReceiptItem? multiLineItem;

        // Cek baris berikutnya (i+1)
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          if (!isUniversalHeaderOrFooter(nextLine)) {
            multiLineItem = _tryParseMultiLineItem(line, nextLine);
            if (multiLineItem != null) {
              _addItemIfNotExists(items, multiLineItem);
              i += 2; // Lewati nama dan baris harga
              continue;
            }

            // Cek 3 baris: baris i (Nama), baris i+1 (Qty/Unit Price), baris i+2 (Subtotal)
            if (i + 2 < lines.length) {
              final lineThree = lines[i + 2];
              if (!isUniversalHeaderOrFooter(lineThree)) {
                multiLineItem = _tryParseThreeLineItem(line, nextLine, lineThree);
                if (multiLineItem != null) {
                  _addItemIfNotExists(items, multiLineItem);
                  i += 3;
                  continue;
                }
              }
            }
          }
        }
      }

      i++;
    }

    return items;
  }

  /// Mencoba parsing item yang berada dalam satu baris tunggal
  static ReceiptItem? _tryParseSingleLineItem(String line) {
    final matches = priceRegex.allMatches(line).toList();
    if (matches.isEmpty) return null;

    // Ambil kecocokan harga paling kanan sebagai subtotal harga item
    final lastPriceMatch = matches.last;
    final priceStr = lastPriceMatch.group(1);
    if (priceStr == null) return null;

    final totalPrice = parseFormattedNumber(priceStr);
    if (totalPrice == null || totalPrice < 100 || totalPrice > 50000000) {
      return null;
    }

    // Bagian teks nama berada di sebelah kiri harga terakhir
    var namePart = line.substring(0, lastPriceMatch.start).trim();
    if (namePart.isEmpty || !_hasAlphabetic(namePart)) return null;

    // Ekstrak kuantitas (jika ada)
    var qty = 1;
    double? unitPrice;

    for (final pattern in _qtyPatterns) {
      final qtyMatch = pattern.firstMatch(namePart);
      if (qtyMatch != null) {
        final parsedQty = int.tryParse(qtyMatch.group(1) ?? '');
        if (parsedQty != null && parsedQty > 0 && parsedQty <= 999) {
          qty = parsedQty;
          namePart = namePart.replaceFirst(pattern, ' ').trim();
          break;
        }
      }
    }

    // Cek apakah ada unit price seperti "@15.000" dalam nama
    final unitPriceMatch = RegExp(r'@\s*([0-9.,]+)').firstMatch(namePart);
    if (unitPriceMatch != null) {
      final parsedUnit = parseFormattedNumber(unitPriceMatch.group(1) ?? '');
      if (parsedUnit != null && parsedUnit > 0) {
        unitPrice = parsedUnit;
      }
      namePart = namePart.replaceAll(RegExp(r'@\s*[0-9.,]+'), ' ').trim();
    }

    final cleanedName = _cleanItemName(namePart);
    if (cleanedName.length < 2 || !_hasAlphabetic(cleanedName)) return null;

    final finalUnitPrice = unitPrice ?? (qty > 1 ? (totalPrice / qty).roundToDouble() : totalPrice);

    return ReceiptItem(
      name: _capitalizeItemName(cleanedName),
      qty: qty,
      unitPrice: finalUnitPrice,
    );
  }

  /// Mencoba parsing item dengan format 2 baris (Baris 1 = Nama, Baris 2 = Qty / Harga)
  static ReceiptItem? _tryParseMultiLineItem(String nameLine, String priceLine) {
    final matches = priceRegex.allMatches(priceLine).toList();
    if (matches.isEmpty) return null;

    final lastPriceMatch = matches.last;
    final priceStr = lastPriceMatch.group(1);
    if (priceStr == null) return null;

    final totalPrice = parseFormattedNumber(priceStr);
    if (totalPrice == null || totalPrice < 100 || totalPrice > 50000000) {
      return null;
    }

    var qty = 1;
    double? unitPrice;

    // Cari kuantitas pada baris harga atau baris nama
    for (final pattern in _qtyPatterns) {
      final match = pattern.firstMatch(priceLine) ?? pattern.firstMatch(nameLine);
      if (match != null) {
        final parsedQty = int.tryParse(match.group(1) ?? '');
        if (parsedQty != null && parsedQty > 0 && parsedQty <= 999) {
          qty = parsedQty;
          break;
        }
      }
    }

    // Jika ada lebih dari 1 angka harga di baris kedua, misal: "2 x 5.000   10.000"
    if (matches.length >= 2) {
      final firstPrice = parseFormattedNumber(matches.first.group(1) ?? '');
      if (firstPrice != null && firstPrice > 0) {
        unitPrice = firstPrice;
      }
    }

    final cleanedName = _cleanItemName(nameLine);
    if (cleanedName.length < 2 || !_hasAlphabetic(cleanedName)) return null;

    final finalUnitPrice = unitPrice ?? (qty > 1 ? (totalPrice / qty).roundToDouble() : totalPrice);

    return ReceiptItem(
      name: _capitalizeItemName(cleanedName),
      qty: qty,
      unitPrice: finalUnitPrice,
    );
  }

  /// Mencoba parsing item 3 baris (Baris 1: Nama, Baris 2: Qty @ UnitPrice, Baris 3: Subtotal)
  static ReceiptItem? _tryParseThreeLineItem(
    String nameLine,
    String qtyLine,
    String subtotalLine,
  ) {
    final subtotalMatch = priceRegex.firstMatch(subtotalLine);
    if (subtotalMatch == null) return null;

    final subtotal = parseFormattedNumber(subtotalMatch.group(1) ?? '');
    if (subtotal == null || subtotal < 100 || subtotal > 50000000) return null;

    var qty = 1;
    for (final pattern in _qtyPatterns) {
      final match = pattern.firstMatch(qtyLine);
      if (match != null) {
        final parsedQty = int.tryParse(match.group(1) ?? '');
        if (parsedQty != null && parsedQty > 0 && parsedQty <= 999) {
          qty = parsedQty;
          break;
        }
      }
    }

    final cleanedName = _cleanItemName(nameLine);
    if (cleanedName.length < 2 || !_hasAlphabetic(cleanedName)) return null;

    return ReceiptItem(
      name: _capitalizeItemName(cleanedName),
      qty: qty,
      unitPrice: (qty > 1 ? (subtotal / qty).roundToDouble() : subtotal),
    );
  }

  static bool _isPlausibleItemName(String line) {
    final trimmed = line.trim();
    if (trimmed.length < 2) return false;
    if (isUniversalHeaderOrFooter(trimmed)) return false;
    return _hasAlphabetic(trimmed);
  }

  static bool _hasAlphabetic(String text) {
    return RegExp(r'[A-Za-z]').hasMatch(text);
  }

  static String _cleanItemName(String name) {
    return name
        .replaceAll(RegExp(r'\b(?:rp|idr)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ÖØ-öø-ÿ&/()\-\s.,]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\-.*:;,_]+|[\-.*:;,_]+$'), '')
        .trim();
  }

  static void _addItemIfNotExists(List<ReceiptItem> items, ReceiptItem item) {
    final exists = items.any(
      (existing) =>
          existing.name.toLowerCase() == item.name.toLowerCase() &&
          existing.qty == item.qty &&
          (existing.unitPrice - item.unitPrice).abs() < 1,
    );
    if (!exists) {
      items.add(item);
    }
  }

  /// Merapikan kapitalisasi nama item
  static String _capitalizeItemName(String name) {
    if (name.isEmpty) return name;
    if (name == name.toUpperCase() && name.length > 3) {
      return name
          .split(' ')
          .map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          })
          .join(' ');
    }
    return name[0].toUpperCase() + name.substring(1);
  }

  // =====================================================================
  // 6. EKSTRAKSI NAMA TOKO & KATEGORI TRANSAKSI
  // =====================================================================

  /// Ekstrak nama toko / merchant dari bagian atas struk
  static String extractMerchantTitle(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 2)
        .toList();

    for (final line in lines.take(5)) {
      final upper = line.toUpperCase();
      if (upper.contains('STRUK') ||
          upper.contains('RECEIPT') ||
          upper.contains('BUKTI') ||
          upper.contains('SELAMAT DATANG') ||
          upper.contains('WELCOME') ||
          upper.contains('TANGGAL') ||
          upper.contains('CETAK ULANG') ||
          upper.contains('REPRINT') ||
          isReceiptSeparatorLine(line)) {
        continue;
      }
      return line;
    }

    return 'Transaksi Struk';
  }

  /// Kamus kata kunci untuk pencocokan kategori transaksi
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

  /// Mencocokkan teks struk dengan kategori yang ada atau membuat baru
  static Future<({CategoryModel category, bool isNewCreated})>
  matchOrSuggestCategory({
    required String rawText,
    required List<CategoryModel> existingCategories,
    CategoryProvider? categoryProvider,
    bool autoCreateIfNotFound = true,
  }) async {
    final lowerText = rawText.toLowerCase();

    // 1. Cek kecocokan nama kategori yang ada dalam teks
    for (final cat in existingCategories) {
      final catNameLower = cat.name.toLowerCase();
      if (catNameLower.length > 3 && lowerText.contains(catNameLower)) {
        return (category: cat, isNewCreated: false);
      }
    }

    // 2. Cocokkan kata kunci kamus
    for (final entry in categoryKeywords.entries) {
      final targetCategoryName = entry.key;
      final keywords = entry.value;

      final hasMatch = keywords.any(
        (kw) => lowerText.contains(kw.toLowerCase()),
      );
      if (hasMatch) {
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

    // 3. Fallback jika tidak ditemukan
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
