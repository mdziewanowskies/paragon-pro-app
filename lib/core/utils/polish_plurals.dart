class PolishPlurals {
  PolishPlurals._();

  static String receipts(int count) {
    if (count == 1) return '1 paragon';
    if (count >= 2 && count <= 4) return '$count paragony';
    return '$count paragonów';
  }

  static String stores(int count) {
    if (count == 1) return '1 sklep';
    if (count >= 2 && count <= 4) return '$count sklepy';
    return '$count sklepów';
  }

  static String months(int count) {
    if (count == 1) return '1 miesiąc';
    if (count >= 2 && count <= 4) return '$count miesiące';
    return '$count miesięcy';
  }

  static String points(int count) {
    if (count == 1) return '1 punkt';
    if (count >= 2 && count <= 4) return '$count punkty';
    return '$count punktów';
  }
}
