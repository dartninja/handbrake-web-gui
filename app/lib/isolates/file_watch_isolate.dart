import 'dart:isolate';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../enums/stream_types.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:app/data/stream_data.dart';

class FileWatchIsolate {
  static final Logger _log = new Logger('HandbrakeIsolate');

  StreamController<NewFileEvent> _newFileStreamController =
      new StreamController<NewFileEvent>();
  Stream<NewFileEvent> get newFile => _newFileStreamController.stream;

  StreamController<DeleteFileEvent> _deleteFileStreamController =
      new StreamController<DeleteFileEvent>();
  Stream<DeleteFileEvent> get deleteFile => _deleteFileStreamController.stream;

  String watchPath;

  final ReceivePort _isolateReceivePort = new ReceivePort();
  SendPort _isolateSendPort;

  Isolate _isolate;

  FileWatchIsolate(this.watchPath) {
    _isolateReceivePort.listen((dynamic data) {
      try {
        if (data is NewFileEvent) {
          _newFileStreamController.add(data);
        } else if (data is DeleteFileEvent) {
          _deleteFileStreamController.add(data);
        } else if (data is SendPort) {
          _isolateSendPort = data;
        }
      } catch(e,st) {
        _log.severe("_isolateReceivePort.listen",e,st);
      }
    });
  }

  Future<void> start() async {
    if (_isolate != null) {
      throw new Exception("Isolate is already running");
    }

    _isolate = await Isolate.spawn(
        _startIsolate,
        new FileWatcherIsolateConfig()
          ..port = _isolateReceivePort.sendPort
          ..path = watchPath);
  }

  static final Map<String, StreamSubscription> watchers =
      <String, StreamSubscription>{};

  static void _startIsolate(FileWatcherIsolateConfig config) async {
    try {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });

      ReceivePort receivePort = new ReceivePort();
      config.port.send(receivePort.sendPort);

      receivePort.listen((dynamic data) async {
        try {
          switch (data) {
            default:
              throw new Exception("Unknown command to isolate: $data");
          }
        } catch (e, st) {
          _log.severe("receivePort.listen", e, st);
        }
      });

      Directory inputDirectory = new Directory(config.path);
      if (!(await inputDirectory.exists())) {
        await inputDirectory.create(recursive: true);
      }

      watchers[config.path] = inputDirectory
          .watch()
          .listen((FileSystemEvent e) => _fileEventHandler(e, config.port));

      await _crawlFolders(inputDirectory, config.port);
    } catch(e,st) {
      _log.severe("_startIsolate",e,st);
    }
  }

  static void _fileEventHandler(FileSystemEvent e, SendPort sendPort) async {
    try {
      FileSystemEntityType type = FileSystemEntity.typeSync(e.path);
      switch (e.type) {
        case FileSystemEvent.create:
          switch (type) {
            case FileSystemEntityType.file:
              try {
                NewFileEvent nfe = await _collectMediaInfo(e.path);
                sendPort.send(nfe);
              } catch (ex, st) {
                _log.warning(
                    "Error while collecting media info for ${e.path}", ex, st);
              }
              break;
            case FileSystemEntityType.directory:
              Directory d = new Directory(e.path);
              watchers[e.path] = d
                  .watch()
                  .listen((FileSystemEvent e) =>
                  _fileEventHandler(e, sendPort));
              break;
          }
          break;
        case FileSystemEvent.delete:
          switch (type) {
            case FileSystemEntityType.file:
              DeleteFileEvent dfe = new DeleteFileEvent();
              dfe.path = e.path;
              sendPort.send(dfe);
              break;
            case FileSystemEntityType.directory:
              if (watchers.containsKey(e.path)) {
                await watchers[e.path].cancel();
                watchers.remove(e.path);
              }
              break;
          }
          break;
        case FileSystemEvent.modify:
          switch (type) {
            case FileSystemEntityType.file:
              try {
                NewFileEvent nfe = await _collectMediaInfo(e.path);
                sendPort.send(nfe);
              } catch (ex, st) {
                _log.warning(
                    "Error while collecting media info for ${e.path}", ex, st);
              }
              break;
          }
          break;
      }
    } catch(e,st) {
      _log.severe("_fileEventHandler",e,st);
    }
  }

  static Future<void> _crawlFolders(Directory dir, SendPort sendPort) async {
    await for (FileSystemEntity fse in dir.list()) {
      if (fse is Directory) {
        await _crawlFolders(fse, sendPort);
        watchers[fse.path] = fse
            .watch()
            .listen((FileSystemEvent e) => _fileEventHandler(e, sendPort));
      } else if (fse is File) {
        try {
          NewFileEvent e = await _collectMediaInfo(fse.path);
          sendPort.send(e);
        } catch (e, st) {
          _log.warning(
              "Error while collecting media info for ${fse.path}", e, st);
        }
      }
    }
  }

  static Future<NewFileEvent> _collectMediaInfo(String inputFile) async {
    NewFileEvent output = new NewFileEvent(inputFile);

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

class FileWatcherIsolateConfig {
  SendPort port;
  String path;
}

class NewFileEvent {
  String path, type;
  num duration, size;
  List<StreamData> streams = <StreamData>[];
  NewFileEvent(this.path);
}

class DeleteFileEvent {
  String path;
}
