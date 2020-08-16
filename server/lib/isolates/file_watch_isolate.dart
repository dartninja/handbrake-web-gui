import 'dart:isolate';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../enums/stream_types.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:parkingbrake_server/data/stream_data.dart';
import 'package:parkingbrake_server/shared.dart';
import '../data/language.dart';

class FileWatchIsolate {
  static final Logger _log = new Logger('HandbrakeIsolate');

  final StreamController<NewFileEvent> _newFileStreamController =
      new StreamController<NewFileEvent>();
  Stream<NewFileEvent> get newFile => _newFileStreamController.stream;

  final StreamController<DeleteFileEvent> _deleteFileStreamController =
      new StreamController<DeleteFileEvent>();
  Stream<DeleteFileEvent> get deleteFile => _deleteFileStreamController.stream;

  String watchPath;

  final ReceivePort _isolateReceivePort = new ReceivePort();
  SendPort _isolateSendPort;

  Isolate _isolate;

  static final Map<String, DateTime> filesAlreadyFound = <String, DateTime>{};

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
      } catch (e, st) {
        _log.severe("_isolateReceivePort.listen", e, st);
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

//  static final Map<String, StreamSubscription> watchers =
//      <String, StreamSubscription>{};

  static void _startIsolate(FileWatcherIsolateConfig config) async {
    try {
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen(logToConsole);

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

//      watchers[config.path] = inputDirectory
//          .watch()
//          .listen((FileSystemEvent e) => _fileEventHandler(e, config.port));

      while (true) {
        await _crawlFolders(inputDirectory, config.port);

        sleep(new Duration(seconds: 15));
      }
    } catch (e, st) {
      _log.severe("_startIsolate", e, st);
    }
  }

//  static void _fileEventHandler(FileSystemEvent e, SendPort sendPort) async {
//    try {
//      FileSystemEntityType type = FileSystemEntity.typeSync(e.path);
//      switch (e.type) {
//        case FileSystemEvent.create:
//          switch (type) {
//            case FileSystemEntityType.file:
//              try {
//                _log.finest("New file found: ${e.path}");
//                NewFileEvent nfe = await _collectMediaInfo(e.path);
//                sendPort.send(nfe);
//              } catch (ex, st) {
//                _log.warning(
//                    "Error while collecting media info for ${e.path}", ex, st);
//              }
//              break;
//            case FileSystemEntityType.directory:
//              Directory d = new Directory(e.path);
//              watchers[e.path] = d
//                  .watch()
//                  .listen((FileSystemEvent e) =>
//                  _fileEventHandler(e, sendPort));
//              break;
//          }
//          break;
//        case FileSystemEvent.delete:
//          switch (type) {
//            case FileSystemEntityType.file:
//              _log.finest("File deleted: ${e.path}");
//              DeleteFileEvent dfe = new DeleteFileEvent();
//              dfe.path = e.path;
//              sendPort.send(dfe);
//              break;
//            case FileSystemEntityType.directory:
//              if (watchers.containsKey(e.path)) {
//                await watchers[e.path].cancel();
//                watchers.remove(e.path);
//              }
//              break;
//          }
//          break;
//        case FileSystemEvent.modify:
//          switch (type) {
//            case FileSystemEntityType.file:
//              try {
//                NewFileEvent nfe = await _collectMediaInfo(e.path);
//                sendPort.send(nfe);
//              } catch (ex, st) {
//                _log.warning(
//                    "Error while collecting media info for ${e.path}", ex, st);
//              }
//              break;
//          }
//          break;
//      }
//    } catch(e,st) {
//      _log.severe("_fileEventHandler",e,st);
//    }
//  }

  static Future<void> _crawlFolders(Directory dir, SendPort sendPort) async {
    _log.finest("_crawlFolders(Directory $dir, SendPort sendPort)");
    List<String> files = new List<String>.from(filesAlreadyFound.keys);

    for (String filePath in files) {
      File f = new File(filePath);
      if (!f.existsSync()) {
        _log.finest("File gone: $filePath");
        DeleteFileEvent dfe = new DeleteFileEvent();
        dfe.path = filePath;
        sendPort.send(dfe);
        filesAlreadyFound.remove(filePath);
      }
    }

    List<FileSystemEntity> dirFiles =
        await dir.listSync(recursive: true, followLinks: false);

    dirFiles.sort((FileSystemEntity fse1, FileSystemEntity fse2) =>
        fse1.path.compareTo(fse2.path));

    for (FileSystemEntity fse in dirFiles) {
      if (fse is Directory) {
        continue;
        //await _crawlFolders(fse, sendPort);
//        watchers[fse.path] = fse
//            .watch()
//            .listen((FileSystemEvent e) => _fileEventHandler(e, sendPort));
      } else if (fse is File) {
        try {
          DateTime lastModified = await fse.lastModified();
          if (filesAlreadyFound.containsKey(fse.path) &&
              filesAlreadyFound[fse.path] == lastModified) {
            // This file is already known of, skip it!
            continue;
          }
          _log.finest("New file found: ${fse.path}");
          NewFileEvent e;
          if (path.basename(fse.path).toLowerCase() == settingsFileName) {
            e = new NewFileEvent(fse.path);
            e.type = "json";
            e.size = await fse.length();
          } else {
            e = await _collectMediaInfo(fse.path);
          }
          sendPort.send(e);
          filesAlreadyFound[fse.path] = lastModified;
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
      '-show_streams',
      '-show_chapters'
    ]);
    if (result.exitCode != 0) {
      final String error = result.stderr.toString();
      throw new Exception("Error while getting audio stream data: $error");
    } else {
      final String probeResults = result.stdout.toString();

      _log.finest("ffprobe output", probeResults);

      Map data = jsonDecode(probeResults);

      Map format = data["format"];
      List streams = data["streams"];

      output.type = format["format_long_name"];
      output.duration = num.parse(format["duration"]);
      output.size = num.parse(format["size"]);

      output.chapters = data["chapters"].length;

      for (Map stream in streams) {
        StreamData streamData = new StreamData()
          ..codec = stream["codec_name"]
          ..index = stream["index"];

        switch (stream["codec_type"]) {
          case "video":
            streamData.profile= stream["profile"];
            streamData.width = stream["width"];
            streamData.height = stream["height"];
            streamData.type = StreamTypes.video;
            break;
          case "audio":
            streamData.type = StreamTypes.audio;
            streamData.channels = stream["channels"];
            streamData.profile= stream["profile"];
            streamData.language = stream["tags"]["language"]??stream["tags"]["LANGUAGE"]??Language.Undetermined;
            streamData.duration = stream["tags"]["DURATION-eng"];
            break;
          case "subtitle":
            streamData.type = StreamTypes.subtitle;
            streamData.language = stream["tags"]["language"]??stream["tags"]["LANGUAGE"]??Language.Undetermined;
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
  num duration, size, chapters;
  List<StreamData> streams = <StreamData>[];

  NewFileEvent(this.path);
}

class DeleteFileEvent {
  String path;
}
