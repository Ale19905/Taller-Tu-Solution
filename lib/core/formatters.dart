import 'package:intl/intl.dart';

final _moneyFormatter = NumberFormat('#,##0.00', 'es');


String money(int cents) => '\$ ${_moneyFormatter.format(cents / 100)}';
String dateLabel(DateTime date) => DateFormat('dd/MM/yyyy • HH:mm', 'es').format(date);

/// We store monetary amounts as integer cents to avoid floating point errors.
/// Accepts both 1234,50 and 1234.50, and separators for thousands.
int? parseMoney(String input) {
  var value = input.trim().replaceAll(' ', '');
  if (value.isEmpty) return null;
  final lastComma = value.lastIndexOf(',');
  final lastDot = value.lastIndexOf('.');
  final decimalIndex = lastComma > lastDot ? lastComma : lastDot;
  if (decimalIndex >= 0) {
    final fractionalLength = value.length - decimalIndex - 1;
    // Spanish thousands: 1.000 and 1.250.000. Treat 3-digit groups as
    // thousands (the app only allows up to 2 decimal places).
    if (fractionalLength == 3 &&
        ((value.contains('.') && !value.contains(',')) ||
         (value.contains(',') && !value.contains('.')))) {
      final thousands = value.replaceAll(RegExp(r'[.,]'), '');
      final parsed = int.tryParse(thousands);
      return parsed == null ? null : parsed * 100;
    }
    if (fractionalLength > 2 || fractionalLength == 0) return null;
    final integerPart = value.substring(0, decimalIndex).replaceAll(RegExp(r'[.,]'), '');
    final fractionalPart = value.substring(decimalIndex + 1);
    if (!RegExp(r'^\d+$').hasMatch(integerPart) ||
        !RegExp(r'^\d+$').hasMatch(fractionalPart)) return null;
    return int.parse(integerPart) * 100 +
        int.parse(fractionalPart.padRight(2, '0'));
  }
  final integerValue = int.tryParse(value);
  return integerValue == null ? null : integerValue * 100;
}
