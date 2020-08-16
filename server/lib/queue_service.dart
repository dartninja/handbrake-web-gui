import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'queue_entry.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'isolates/handbrake_isolate.dart';
import 'isolates/file_watch_isolate.dart';
import 'package:parkingbrake_server/shared.dart';
import 'dart:isolate';

class QueueService {
  static final Logger _log = new Logger('QueueService');

  final String inputPath, outputPath, trashPath;
  final String ffprobePath;
  final String handbrakePath;

  Directory inputDir;

  Map<String,dynamic> globalSettings = <String,dynamic>{};
  final Map<String, Map> settings = <String, Map>{};
  final List<QueueEntry> entries = <QueueEntry>[];

  QueueService(this.inputPath, this.outputPath, this.trashPath,
      this.ffprobePath, this.handbrakePath, this.globalSettings) {
    inputDir = new Directory(this.inputPath);
    if (!inputDir.existsSync()) {
      inputDir.createSync();
      //throw new Exception("Input path does not exist: $inputPath");
    }
    _handbrakeIsolate = new HandbrakeIsolate(_getNextHandbrakeJob);

    _handbrakeIsolate.progress.listen((HandbrakeIsolateProgress progress) {
      try {
        QueueEntry entry = getQueueEntry(progress.jobId);
        entry?.status = QueueEntryStatus.active;
        entry?.progress = progress.progress;
      } catch (e, st) {
        _log.severe("_handbrakeIsolate.progress.listen", e, st);
      }
    });
    _handbrakeIsolate.complete.listen((HandbrakeIsolateComplete complete) {
      try {
        QueueEntry entry = getQueueEntry(complete.jobId);
        if ((complete.error ?? "").isEmpty) {
          entry?.status = QueueEntryStatus.complete;
        } else {
          entry?.status = QueueEntryStatus.issue;
        }
        entry?.progress = 1;
      } catch (e, st) {
        _log.severe("_handbrakeIsolate.complete.listen", e, st);
      }
    });

    _fileWatchIsolate = new FileWatchIsolate(inputPath);
    _fileWatchIsolate.newFile.listen((NewFileEvent e) async {
      try {
        if (path.basename(e.path).toLowerCase() == settingsFileName) {
          await _applySettingsFile(e.path);
        } else {
          if (getQueueEntryForPath(e.path) != null) return;

          final QueueEntry entry = new QueueEntry()
            ..fullPath = e.path
            ..path = e.path.substring(this.inputPath.length + 1)
            ..dir = path.dirname(e.path)
            ..name = path.basename(e.path)
            ..streams = e.streams
            ..duration = e.duration
            ..size = e.size
            ..chapters = e.chapters
            ..type = e.type;

          entry.applySettings(globalSettings);
          if (settings.containsKey(entry.dir)) {
            entry.applySettings(settings[entry.dir]);
          }
          entries.add(entry);
        }
      } catch (e, st) {
        _log.severe("_fileWatchIsolate.newFile.listen", e, st);
      }
    });
    _fileWatchIsolate.deleteFile.listen((DeleteFileEvent e) {
      try {
        if (path.basename(e.path).toLowerCase() == settingsFileName) {
          _removeSettingsFile(e.path);
        } else {
          QueueEntry qe = getQueueEntryForPath(e.path);

          if (qe == null || qe.status != QueueEntryStatus.complete) {
            entries.remove(qe);
          }
        }
      } catch (e, st) {
        _log.severe("_fileWatchIsolate.deleteFile.listen", e, st);
      }
    });
  }

  void _removeSettingsFile(String filePath) {
    String dir = path.dirname(filePath);
    if (settings.containsKey(dir)) {
      settings.remove(dir);
    }

    for (QueueEntry qe in entries) {
      if (qe.status != QueueEntryStatus.pending) {
        continue;
      }
      if (qe.dir == dir) {
        qe.resetSettings();
      }
    }
  }

  Future<void> _applySettingsFile(String filePath) async {
    final File f = new File(filePath);
    String dir = path.dirname(filePath);
    String contents = await f.readAsString();
    Map data;
    try {
      data = jsonDecode(contents);
    } catch (e, st) {
      _log.warning("Unable to decode $filePath: ${e.message}", st);
    }
    this.settings[dir] = data;

    for (QueueEntry qe in entries) {
      if (qe.status != QueueEntryStatus.pending) {
        continue;
      }
      if (qe.dir == dir) {
        qe.resetSettings();
        qe.applySettings(this.globalSettings);
        qe.applySettings(data);
      }
    }
  }

  QueueEntry getQueueEntry(String id) => this
      .entries
      .firstWhere((QueueEntry qe) => qe.id == id, orElse: () => null);
  QueueEntry getQueueEntryForPath(String path) => this
      .entries
      .firstWhere((QueueEntry qe) => qe.fullPath == path, orElse: () => null);

  void clearComplete() => entries.removeWhere(
      (QueueEntry entry) => entry.status == QueueEntryStatus.complete);

  QueueEntry getNextQueueEntry() {
    for (int i = 0; i < entries.length; i++) {
      QueueEntry entry = entries[i];
      if (entry.status == QueueEntryStatus.active ||
          entry.status == QueueEntryStatus.pending) {
        File f = new File(entry.fullPath);
        if (!f.existsSync()) {
          entries.removeAt(i);
          i--;
        } else {
          return entry;
        }
      }
    }
    return null;
  }

  bool shutdown = false;

  HandbrakeIsolate _handbrakeIsolate;
  FileWatchIsolate _fileWatchIsolate;

  HandbrakeIsolateConfig _getNextHandbrakeJob() {
    QueueEntry nextEntry = getNextQueueEntry();
    if (nextEntry == null) return null;

    return new HandbrakeIsolateConfig(inputPath, outputPath, trashPath,
        ffprobePath, handbrakePath, nextEntry);
  }

  Future<void> init() async {
    _handbrakeIsolate.start();
    _fileWatchIsolate.start();
  }
}
