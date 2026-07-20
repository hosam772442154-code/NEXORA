import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class TimeService {
  /// Returns the current time locked to Asia/Aden timezone (UTC +3)
  static DateTime getAdenTime() {
    final now = DateTime.now().toUtc();
    return now.add(const Duration(hours: 3));
  }

  /// Returns the time formatted strictly into a 12-hour format with localized Arabic markers
  static String getAdenFormattedTime() {
    final adenTime = getAdenTime();
    String formatted = DateFormat('hh:mm a').format(adenTime);
    return formatted.replaceAll('AM', 'صباحًا').replaceAll('PM', 'مساءً')
                    .replaceAll('am', 'صباحًا').replaceAll('pm', 'مساءً');
  }

  /// Returns the date as 'yyyy-MM-dd'
  static String getAdenFormattedDate() {
    final adenTime = getAdenTime();
    return DateFormat('yyyy-MM-dd').format(adenTime);
  }

  /// Compares the given ISO string expiry date with the current synchronized Aden time
  /// to determine if a temporary ban has ended.
  static bool hasBanExpired(String banExpiryIsoString) {
    try {
      final expiryDate = DateTime.parse(banExpiryIsoString);
      final currentAdenTime = getAdenTime();
      return currentAdenTime.isAfter(expiryDate);
    } catch (e) {
      debugPrint('Error parsing ban expiry date: $e');
      return false;
    }
  }
}
