import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _datePl = DateFormat('dd.MM.yyyy');
  static final _dateTimePl = DateFormat('dd.MM.yyyy HH:mm');
  static final _monthYearPl = DateFormat('MMMM yyyy', 'pl_PL');
  static final _currencyPl = NumberFormat.currency(
    locale: 'pl_PL',
    symbol: 'zł',
    decimalDigits: 2,
  );

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return _datePl.format(date);
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimePl.format(date);
  }

  static String formatMonthYear(DateTime date) {
    return _monthYearPl.format(date);
  }

  static String formatRelativeDate(DateTime? date) {
    if (date == null) return '-';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return 'Dzisiaj';
    if (diff == 1) return 'Wczoraj';
    if (diff <= 7) return '$diff dni temu';
    return formatDate(date);
  }

  static String formatCurrency(double? amount) {
    if (amount == null) return '0,00 zł';
    return _currencyPl.format(amount);
  }

  static String formatCurrencyShort(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M zł';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K zł';
    }
    return formatCurrency(amount);
  }

  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        return _datePl.parse(dateStr);
      } catch (_) {
        return null;
      }
    }
  }

  static String daysUntil(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff < 0) return 'Wygasła ${-diff} dni temu';
    if (diff == 0) return 'Wygasa dzisiaj';
    if (diff == 1) return 'Wygasa jutro';
    return 'Wygasa za $diff dni';
  }
}
