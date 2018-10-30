import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'queue_entry.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'isolates/handbrake_isolate.dart';
import 'dart:isolate';

class QueueService {
  static final Logger _log = new Logger('QueueService');

  final String inputPath, outputPath, completePath;
  final String ffprobePath;
  final String handbrakePath;

  Directory inputDir;

  final List<QueueEntry> entries = <QueueEntry>[];

  QueueService(
      this.inputPath, this.outputPath, this.completePath, this.ffprobePath, this.handbrakePath) {
    inputDir = new Directory(this.inputPath);
    if (!inputDir.existsSync()) {
      throw new Exception("Input path does not exist: $inputPath");
    }
    _handbrakeIsolate = new HandbrakeIsolate(_getNextHandbrakeJob);

    _handbrakeIsolate.progress.listen((HandbrakeIsolateProgress progress) {
      QueueEntry entry =getQueueEntry(progress.jobId);
      entry?.status = QueueEntryStatus.active;
      entry?.progress = progress.progress;
    });
    _handbrakeIsolate.complete.listen((HandbrakeIsolateComplete complete) {
      QueueEntry entry =getQueueEntry(complete.jobId);
      if((complete.error??"").isEmpty) {
        entry?.status = QueueEntryStatus.complete;
      } else {
        entry?.status = QueueEntryStatus.issue;
      }
      entry?.progress = 1;
    });

  }

  QueueEntry getQueueEntry(String id) => this.entries.firstWhere((QueueEntry qe)=> qe.id==id);


  QueueEntry getNextQueueEntry() {
    for (QueueEntry entry in entries) {
      if (entry.status == QueueEntryStatus.active ||
          entry.status == QueueEntryStatus.pending) return entry;
    }
    return null;
  }

  bool shutdown = false;

  HandbrakeIsolate _handbrakeIsolate;

  HandbrakeIsolateConfig _getNextHandbrakeJob() {
    QueueEntry nextEntry = getNextQueueEntry();
    if(nextEntry==null)
      return null;

    return new HandbrakeIsolateConfig(inputPath, outputPath, completePath, ffprobePath, handbrakePath, nextEntry);
  }

  Future<void> init() async {
    for (File f in await _crawlFolders(inputDir)) {
      entries.add(await _collectMediaInfo(f.path, inputDir.path));
    }

    _handbrakeIsolate.start();
  }

  Future<List<File>> _crawlFolders(Directory dir) async {
    final List<File> output = <File>[];
    await for (FileSystemEntity fse in dir.list()) {
      if (fse is Directory) {
        output.addAll(await _crawlFolders(fse));
      } else if (fse is File) {
        output.add(fse);
      }
    }
    return output;
  }

  Future<QueueEntry> _collectMediaInfo(String inputFile, String rootPath) async {
    QueueEntry output = new QueueEntry()
      ..fullPath = inputFile
      ..path = inputFile.substring(rootPath.length+1)
      ..name = path.basename(inputFile);

    ProcessResult result = await Process.run("ffprobe", <String>[
      '-i',
      inputFile,
      '-show_streams',
      '-v',
      'quiet',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams'
    ]);
    if (result.exitCode != 0) {
      final String error = result.stderr.toString();
      throw new Exception("Error while getting audio stream data: $error");
    } else {
      final String probeResults = result.stdout.toString();

      Map data = jsonDecode(probeResults);

      Map format = data["format"];
      List streams = data["streams"];

      output.type = format["format_long_name"];
      output.duration = num.parse(format["duration"]);
      output.size = num.parse(format["size"]);

      for (Map stream in streams) {
        StreamData streamData = new StreamData()
          ..codec = stream["codec_name"]
          ..index = stream["index"];

        switch (stream["codec_type"]) {
          case "video":
            streamData.width = stream["width"];
            streamData.height = stream["height"];
            streamData.type = StreamTypes.video;
            break;
          case "audio":
            streamData.type = StreamTypes.audio;
            streamData.channels = stream["channels"];
            break;
          case "subtitle":
            streamData.type = StreamTypes.subtitle;
            streamData.language = stream["tags"]["language"];
            break;
        }

        output.streams.add(streamData);
      }
    }
    return output;
  }
}
