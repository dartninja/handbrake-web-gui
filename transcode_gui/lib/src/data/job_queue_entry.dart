import 'dart:convert';
import 'dart:math';

class JobQueueEntry {
  String id;
  String path;
  String name;
  String status;
  num progress;

  Map rawData;

  int get percent => (progress*100).round();

  JobQueueEntry.fromJson(Map data) {
    this.id = data['id'];
    this.path = data['path'];
    this.name = data['name'];
    this.status = data['status'];
    this.progress = data["progress"];
    this.rawData = data;
  }

  String toString() => jsonEncode(this.rawData);
}