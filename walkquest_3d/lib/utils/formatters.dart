import 'package:intl/intl.dart';

/// Display formatting for distances, durations and counts.
class Fmt {
  Fmt._();

  static const metersPerMile = 1609.344;
  static final _int = NumberFormat.decimalPattern();

  static String distance(double meters, {required bool miles}) {
    if (miles) {
      final mi = meters / metersPerMile;
      return mi < 0.1 ? '${(meters * 3.28084).round()} ft' : '${mi.toStringAsFixed(mi < 10 ? 2 : 1)} mi';
    }
    return meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(meters < 10000 ? 2 : 1)} km';
  }

  /// "14 min", "1 h 05 min".
  static String duration(Duration d) {
    final mins = (d.inSeconds / 60).round();
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60} h ${(mins % 60).toString().padLeft(2, '0')} min';
  }

  /// "05:32" or "1:05:32" stopwatch style.
  static String clock(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static String count(num n) => _int.format(n.round());

  /// "~1,600": rounded to two significant figures for estimates.
  static String approx(num n) {
    if (n < 100) return '~${n.round()}';
    final digits = n.round().toString().length;
    final unit = digits <= 3 ? 10 : 100;
    return '~${_int.format((n / unit).round() * unit)}';
  }

  static String pace(double minPerKm, {required bool miles}) {
    if (minPerKm <= 0 || minPerKm.isInfinite) return '--';
    final p = miles ? minPerKm * metersPerMile / 1000 : minPerKm;
    final m = p.floor();
    final s = ((p - m) * 60).round().toString().padLeft(2, '0');
    return "$m'$s\" /${miles ? 'mi' : 'km'}";
  }

  static String shortDate(DateTime d) => DateFormat.MMMd().format(d);
  static String dateTime(DateTime d) => DateFormat.yMMMd().add_jm().format(d);
  static String weekday(DateTime d) => DateFormat.E().format(d);
}
