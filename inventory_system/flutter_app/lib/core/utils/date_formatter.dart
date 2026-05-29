import 'package:intl/intl.dart';

class DateFormatter {
  static final _istOffset = Duration(hours: 5, minutes: 30);

  static DateTime toIST(DateTime utc) {
    final utcTime = utc.isUtc ? utc : utc.toUtc();
    return utcTime.add(_istOffset);
  }

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final ist = toIST(dt);
    return DateFormat('dd MMM yyyy, hh:mm a').format(ist);
  }

  static String formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final ist = toIST(dt);
    return DateFormat('dd MMM yyyy').format(ist);
  }

  static String formatDateShort(DateTime? dt) {
    if (dt == null) return '-';
    final ist = toIST(dt);
    return DateFormat('dd/MM/yyyy').format(ist);
  }

  static String formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final ist = toIST(dt);
    return DateFormat('hh:mm a').format(ist);
  }

  static String formatApiDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  static DateTime? parseApi(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  static String timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt.isUtc ? dt : dt.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
