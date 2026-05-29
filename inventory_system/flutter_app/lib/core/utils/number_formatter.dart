import 'package:intl/intl.dart';

class NumberFormatter {
  static final _compact = NumberFormat.compact();
  static final _decimal = NumberFormat('#,##0.###');

  static String format(dynamic value) {
    if (value == null) return '0';
    final numVal = num.tryParse(value.toString()) ?? 0;
    if (numVal >= 1000000) return _compact.format(numVal);
    return _decimal.format(numVal);
  }

  static String formatQty(dynamic value) {
    if (value == null) return '0';
    final numVal = num.tryParse(value.toString());
    if (numVal == null) return '0';
    if (numVal == numVal.round()) return numVal.round().toString();
    return numVal.toStringAsFixed(2);
  }

  static String formatCurrency(dynamic value) {
    if (value == null) return '₹0';
    final numVal = num.tryParse(value.toString()) ?? 0;
    if (numVal == numVal.roundToDouble()) {
      return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(numVal);
    } else {
      return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(numVal);
    }
  }
}
