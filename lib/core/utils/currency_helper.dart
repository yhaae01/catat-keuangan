import 'package:intl/intl.dart';

class CurrencyHelper {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format angka ke format mata uang Rupiah (contoh: Rp 150.000)
  static String formatRupiah(double amount) {
    return _formatter.format(amount);
  }

  /// Format tanggal singkat (contoh: 18 Okt 2026)
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return 'Hari ini, ${DateFormat('HH:mm').format(date)}';
    } else if (target == today.subtract(const Duration(days: 1))) {
      return 'Kemarin, ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('d MMM yyyy, HH:mm').format(date);
    }
  }
}
