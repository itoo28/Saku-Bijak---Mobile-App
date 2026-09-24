import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  static String format(int amount) {
    return _formatter.format(amount);
  }

  static int parse(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return TextEditingValue.empty;
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return TextEditingValue.empty;
    }

    final amount = int.tryParse(digitsOnly) ?? 0;
    final formatted = _formatter.format(amount);
    final selectionIndex = _selectionForDigitCount(
      formatted,
      _digitsBeforeCursor(newValue),
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: selectionIndex),
      composing: TextRange.empty,
    );
  }

  int _digitsBeforeCursor(TextEditingValue value) {
    final cursor = value.selection.end.clamp(0, value.text.length);
    final textBeforeCursor = value.text.substring(0, cursor);
    return textBeforeCursor.replaceAll(RegExp(r'[^0-9]'), '').length;
  }

  int _selectionForDigitCount(String text, int digitCount) {
    if (digitCount <= 0) return text.length;

    var seenDigits = 0;
    for (var index = 0; index < text.length; index++) {
      if (RegExp(r'[0-9]').hasMatch(text[index])) {
        seenDigits++;
        if (seenDigits >= digitCount) {
          return index + 1;
        }
      }
    }

    return text.length;
  }
}
