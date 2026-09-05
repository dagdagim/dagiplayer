import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  /// Formats duration as mm:ss (e.g. 03:45) or hh:mm:ss (e.g. 01:23:45)
  static String formatDuration(Duration? duration) {
    if (duration == null || duration.inSeconds < 0) return '0:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final minutesStr = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutesStr:$secondsStr';
    }
    return '$minutesStr:$secondsStr';
  }

  /// Formats long durations into readable strings like "1h 32m" or "45m"
  static String formatDurationLong(Duration? duration) {
    if (duration == null || duration.inSeconds <= 0) return '0m';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Formats byte sizes into B, KB, MB, GB
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Formats large numbers with commas e.g. 1,234
  static String formatCount(int count) {
    return NumberFormat.decimalPattern().format(count);
  }

  /// Formats date
  static String formatDate(DateTime date) {
    return DateFormat.yMMMMd().format(date);
  }
}
