import 'package:logging/logging.dart';
import '../queue_entry.dart';
import 'dart:isolate';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

typedef HandbrakeIsolateConfig GetNextJobFunction();

class HandbrakeIsolate {
  static final Logger _log = new Logger('HandbrakeIsolate');

  static const String requestJob = "GibJob";
  static const String waitForJob = "chillout";
  static const String stopIsolate = "timetodie";

  final StreamController<HandbrakeIsolateProgress> _progressController =
      new StreamController<HandbrakeIsolateProgress>();

  Stream<HandbrakeIsolateProgress> get progress => _progressController.stream;

  final StreamController<HandbrakeIsolateComplete> _completeController =
      new StreamController<HandbrakeIsolateComplete>();

  Stream<HandbrakeIsolateComplete> get complete => _completeController.stream;

  final ReceivePort _isolateReceivePort = new ReceivePort();
  SendPort _isolateSendPort;

  Isolate _isolate;

  final GetNextJobFunction getNextJob;

  HandbrakeIsolate(this.getNextJob) {
    _isolateReceivePort.listen((dynamic data) {
      try {
        if (data is HandbrakeIsolateProgress) {
          _progressController.add(data);
        } else if (data is HandbrakeIsolateComplete) {
          _completeController.add(data);
        } else if (data is SendPort) {
          _isolateSendPort = data;
        } else if (data is String) {
          switch (data) {
            case requestJob:
              final HandbrakeIsolateConfig nextJob = getNextJob();
              if (nextJob == null) {
                _log.finest("No next job available, telling isolate to wait");
                _isolateSendPort.send(waitForJob);
              } else {
                _log.finest("Next job found, sending to isolate");
                _isolateSendPort.send(nextJob);
              }
              break;
            default:
              throw new Exception("Unknown request from isolate: $data");
          }
        }
      } catch (e, st) {
        _log.severe("_isolateReceivePort.listen", e, st);
      }
    });
  }

  Future<void> start() async {
    if (_isolate != null) {
      throw new Exception("Isolate is already running");
    }

    _isolate = await Isolate.spawn(_startIsolate, _isolateReceivePort.sendPort);
  }

  static void _startIsolate(SendPort sendPort) {
    try {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });

      ReceivePort receivePort = new ReceivePort();
      sendPort.send(receivePort.sendPort);

      receivePort.listen((dynamic data) async {
        try {
          if (data is String) {
            switch (data) {
              case waitForJob:
                _log.finest("Isolate told to wait, waiting");
                sleep(new Duration(seconds: 10));
                sendPort.send(requestJob);
                break;
              default:
                throw new Exception("Unknown command to isolate: $data");
            }
          } else if (data is HandbrakeIsolateConfig) {
            _log.finest("Isolate given config, beginning processing");
            await _runHandbrake(data, sendPort);
            sendPort.send(requestJob);
          }
        } catch (e, st) {
          _log.severe("receivePort.listen", e, st);
        }
      });

      sendPort.send(requestJob);
    } catch (e, st) {
      _log.severe("_startIsolate", e, st);
    }
  }

  static void _runHandbrake(
      HandbrakeIsolateConfig config, SendPort sendPort) async {
    String relativePath = config.jobEntry.path;
    String filename = path.basenameWithoutExtension(config.jobEntry.fullPath);

    String outputPath = config.outputDir;
    if (path.dirname(relativePath) != ".") {
      outputPath = path.join(config.outputDir, path.dirname(relativePath));
    }

    Directory d = new Directory(outputPath);
    if (!d.existsSync()) {
      await d.create(recursive: true);
    }

    outputPath = path.join(outputPath, "$filename.mkv");

    _log.info("Encoding to detination: $outputPath");

    List<String> args =
        new List<String>.from(config.jobEntry.encoding.toProcessArgs());

    args.addAll(
        ['--json', '-i', config.jobEntry.fullPath, '-o', "$outputPath"]);

    Process process = await Process.start(config.handbrake, args);

    StringBuffer errorBuffer = new StringBuffer();
    StringBuffer outputBuffer = new StringBuffer();
    String buffer = "";
    HandbrakeIsolateProgress progress =
        new HandbrakeIsolateProgress(config.jobEntry.id);

    process.stdout.transform(utf8.decoder).listen((String data) {
      //_log.finest(data);
      outputBuffer.write(data);
      try {
        buffer = buffer + data;

        int start = buffer.indexOf("Version: {");
        int end = buffer.indexOf("}", buffer.indexOf("}") + 1) + 1;
        if (start >= 0 && end > 0) {
          start += 9;
          String snippet = buffer.substring(start, end);
          Map json = jsonDecode(snippet);
          _log.fine("Succesfully decoded json data: $buffer");
          buffer = buffer.substring(end);
        }

        start = buffer.indexOf("Progress: {");
        end = buffer.indexOf("}", buffer.indexOf("}") + 1) + 1;
        while (start >= 0 && end > 0) {
          start += 10;
          String snippet = buffer.substring(start, end);
          Map json = jsonDecode(snippet);
          _log.fine("Succesfully decoded json data: $buffer");
          buffer = buffer.substring(end);
          start = buffer.indexOf("Progress: {");
          end = buffer.indexOf("}", buffer.indexOf("}") + 1) + 1;
          switch (json["State"]) {
            case "WORKING":
              progress.progress = json["Working"]["Progress"];
              progress.rate = json["Working"]["Rate"];
              progress.remaining = new Duration(
                  hours: json["Working"]["Hours"],
                  minutes: json["Working"]["Minutes"]);
              sendPort.send(progress);
              break;
            case "WORKDONE":
              HandbrakeIsolateComplete complete =
                  new HandbrakeIsolateComplete(config.jobEntry.id);
              if (json["WorkDone"]["Error"] != 0) {
                complete.error = errorBuffer.toString();
              }
              sendPort.send(complete);
              break;
          }
        }
      } catch (e, st) {
        _log.fine("Unable to decode json data: $buffer");
      }
    });

    process.stderr.transform(utf8.decoder).listen((String data) {
      errorBuffer.write(data);
    });

    int exitCode = await process.exitCode;

    File inputFile = new File(config.jobEntry.fullPath);

    String moveTarget = path.join(config.completeDir, config.jobEntry.path);

    Directory moveDir = new Directory(path.dirname(moveTarget));
    if (!(await moveDir.exists())) {
      await moveDir.create(recursive: true);
    }

    await inputFile.rename(moveTarget);

    Directory sourceDir = new Directory(path.dirname(config.jobEntry.fullPath));
    if (sourceDir.path != config.inputDir && sourceDir.listSync().isEmpty) {
      await sourceDir.delete();
    }

    HandbrakeIsolateResult output = new HandbrakeIsolateResult();

    output.error = errorBuffer.toString();
    String outputString = outputPath.toString();

    if (exitCode != 0) {
    } else {}
    //return output;
  }
}

class HandbrakeIsolateResult {
  String error;
}

class HandbrakeIsolateConfig {
  String inputDir, outputDir, completeDir, ffprobe, handbrake;
  //Level loggingLevel;
  QueueEntry jobEntry;

  HandbrakeIsolateConfig(this.inputDir, this.outputDir, this.completeDir,
      this.ffprobe, this.handbrake, this.jobEntry);
}

class HandbrakeIsolateProgress {
  String jobId;
  num progress;
  num rate;
  Duration remaining;

  HandbrakeIsolateProgress(this.jobId);
}

class HandbrakeIsolateComplete {
  String jobId;
  String error;
  HandbrakeIsolateComplete(this.jobId);
}
