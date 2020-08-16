import 'dart:convert';
import 'dart:math' as math;

class JobQueueEntry {
  String id;
  String path;
  String name;
  String status;
  num progress;
  Duration duration;
  int size;

  Map rawData;

  int get percent => (progress * 100).round();

  JobQueueEntry.fromJson(Map data) {
    this.id = data['id'];
    this.path = data['path'];
    this.name = data['name'];
    this.status = data['status'];
    this.progress = data["progress"];
    num dur = data["duration"];
    this.duration = new Duration(milliseconds: dur.toInt() * 1000);
    this.size = data["size"];
    this.rawData = data;
  }

  final JsonEncoder _encoder = new JsonEncoder.withIndent('  ');

  String toString() => _encoder.convert(this.rawData);

  static const Map<String, int> _conversions = const <String, int>{
    "GB": 1073741824,
    "MB": 1048576,
    "KB": 1024,
    "B": 1
  };

  String get sizeString {
    for (String key in _conversions.keys) {
      if (this.size >= _conversions[key]) {
        return "${(size / _conversions[key]).toStringAsFixed(2)}$key";
      }
    }
    return "${size}B";
  }
}
