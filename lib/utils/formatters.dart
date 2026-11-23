import 'package:intl/intl.dart';

/// Shared display formatting so every screen shows money, numbers and dates
/// the same way.
class Fmt {
  Fmt._();

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final NumberFormat _indian = NumberFormat.decimalPattern('en_IN')
    ..maximumFractionDigits = 2;
  static final NumberFormat _western = NumberFormat.decimalPattern('en_US')
    ..maximumFractionDigits = 2;

  static NumberFormat _numberFor(String currencySymbol) =>
      currencySymbol == '₹' ? _indian : _western;

  /// "₹1,500" or "₹1,249.5". Null counts as 0.
  static String money(num? value, String currencySymbol) =>
      '$currencySymbol${_numberFor(currencySymbol).format(value ?? 0)}';

  /// "15,000" or "3.5". Uses Indian grouping when the currency is ₹.
  static String number(num? value, {String currencySymbol = '₹'}) =>
      _numberFor(currencySymbol).format(value ?? 0);

  /// "05 Jan 2026" from an ISO date ("2026-01-05" or a full timestamp).
  /// Returns the input unchanged if it can't be parsed.
  static String date(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? iso : _date.format(parsed);
  }

  /// Number text for an editable field: no grouping and no trailing ".0",
  /// but keeps real decimals (249.5 stays 249.5, 250.0 becomes 250).
  static String editable(num value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(2);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }
}
