import '../../domain/entities/subtitle_track.dart';

class SubtitleParserService {
  SubtitleParserService._();

  static List<SubtitleItem> parseSrt(String srtContent) {
    final items = <SubtitleItem>[];
    final lines = srtContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    int currentIndex = 0;
    Duration? currentStart;
    Duration? currentEnd;
    final textBuffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        if (currentStart != null && currentEnd != null && textBuffer.isNotEmpty) {
          items.add(SubtitleItem(
            index: currentIndex,
            startTime: currentStart,
            endTime: currentEnd,
            text: textBuffer.toString().trim(),
          ));
          textBuffer.clear();
          currentStart = null;
          currentEnd = null;
        }
        continue;
      }

      if (RegExp(r'^\d+$').hasMatch(line) && currentStart == null) {
        currentIndex = int.tryParse(line) ?? currentIndex;
        continue;
      }

      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          currentStart = _parseTimestamp(parts[0].trim());
          currentEnd = _parseTimestamp(parts[1].trim());
        }
        continue;
      }

      if (textBuffer.isNotEmpty) textBuffer.write('\n');
      textBuffer.write(line);
    }

    if (currentStart != null && currentEnd != null && textBuffer.isNotEmpty) {
      items.add(SubtitleItem(
        index: currentIndex,
        startTime: currentStart,
        endTime: currentEnd,
        text: textBuffer.toString().trim(),
      ));
    }

    return items;
  }

  static Duration _parseTimestamp(String timestamp) {
    try {
      // Format: 00:01:20,000 or 00:01:20.000
      final normalized = timestamp.replaceAll(',', '.');
      final parts = normalized.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secParts = parts[2].split('.');
        final seconds = int.parse(secParts[0]);
        final millis = secParts.length > 1 ? int.parse(secParts[1].padRight(3, '0').substring(0, 3)) : 0;

        return Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
      }
    } catch (_) {}
    return Duration.zero;
  }
}
