import 'package:logging/logging.dart';
import 'queue_entry_status.dart';
import 'enums/stream_types.dart';
import 'package:uuid/uuid.dart';
import 'encoding_settings.dart';

export 'queue_entry_status.dart';
export 'enums/stream_types.dart';


class QueueEntry {
  String id =  new Uuid().v4();
  String path;
  String fullPath;
  String name;
  String type;
  num duration;

  EncodingSettings encoding = new EncodingSettings();

  num size;
  List<StreamData> streams = <StreamData>[];
  num progress = 0;

  QueueEntryStatus status = QueueEntryStatus.pending;

  Map toJson() => {
    'id': this.id,
    'path': this.path,
    'name': this.name,
    'status': status.toString().split(".")[1],
    'duration': duration,
    'size': size,
    'type': type,
    //'streams': streams.map((StreamData sd) => sd.toJson()).toList(),
    'progress': progress,
    'args': encoding.toString(),
  };
}

class StreamData {
  static final Logger _log = new Logger('StreamData');
  int index;
  String codec;
  int width, height;
  StreamTypes type;
  String language;
  int channels;


  Map toJson() =>{
    'index': this.index,
        'codec': this.codec,
        'type': type.toString().split(".")[1],
        'width': width,
        'height': height,
        'language': language,
        'channels': channels
      };
}