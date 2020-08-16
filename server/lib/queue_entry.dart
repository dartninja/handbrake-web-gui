import 'package:logging/logging.dart';
import 'queue_entry_status.dart';
import 'enums/stream_types.dart';
import 'package:uuid/uuid.dart';
import 'encoding_settings.dart';
import 'data/stream_data.dart';
import 'data/encoder_job.dart';
import 'data/language.dart';

export 'queue_entry_status.dart';
export 'enums/stream_types.dart';
export 'data/encoder_job.dart';

class QueueEntry {
  static final Logger _log = new Logger('QueueEntry');

  String id = new Uuid().v4();
  String path;
  String fullPath;
  String dir;
  String name;
  String type;
  num duration;

  int chapters;

  int maxHeight = -1;

  int chapterSplit = 0, chapterStart = 0, chapterEnd = 0;
  List<int> chapterSplits = <int>[];

  bool flipSubtitles = false, detectHdSubAudioTrack = false;

  List<String> audioLanguages = <String>[];

  EncodingSettings _encoding = new EncodingSettings();

  num size;
  List<StreamData> streams = <StreamData>[];

  List<StreamData> get audioStreams =>
      streams.where((StreamData sd) => sd.type == StreamTypes.audio).toList();

  num progress = 0;

  QueueEntryStatus status = QueueEntryStatus.pending;


  List<EncoderJob> getEncoderJobs() {
    final List<EncoderJob> output = <EncoderJob>[];

    if (this.chapters > 0) {
      if (chapterSplit > 0) {
        int start = 1,
            lastChapter = this.chapters;
        if (this.chapterEnd > 0 && this.chapterEnd <= this.chapters) {
          lastChapter = this.chapterEnd;
        }

        if (this.chapterStart > 0) {
          start = this.chapterStart;
        }

        while (start <= lastChapter) {
          int end = start + this.chapterSplit - 1;
          if (lastChapter < (end + this.chapterSplit - 1)) {
            end = lastChapter;
          }

          EncoderJob job = _prepareEncoderJob();
          job.args.add("--chapters");
          job.args.add("$start-$end");
          output.add(job);

          start = end + 1;
        }
      } else if(chapterSplits.isNotEmpty) {

        int start = 1,
            lastChapter = this.chapters;
        if (this.chapterEnd > 0 && this.chapterEnd <= this.chapters) {
          lastChapter = this.chapterEnd;
        }

        if (this.chapterStart > 0) {
          start = this.chapterStart;
        }

        for(int i = 0; i < this.chapterSplits.length; i++) {
          int splitPoint = this.chapterSplits[i];

          if(splitPoint < start) {
            continue;
          }

          int end = splitPoint;

          if(end > lastChapter) {
            end = lastChapter;
          }

          EncoderJob job = _prepareEncoderJob();
          job.args.add("--chapters");
          job.args.add("$start-$end");
          output.add(job);

          start = end + 1;

          if(end==lastChapter) {
            break;
          }
        }

        if(start<=lastChapter) {
          EncoderJob job = _prepareEncoderJob();
          job.args.add("--chapters");
          job.args.add("$start-$lastChapter");
          output.add(job);
        }


      } else {
        final EncoderJob job = _prepareEncoderJob();

        int start = 1, end = this.chapters;
        if (this.chapterStart > 0) {
          start = this.chapterStart;
        }
        if (this.chapterEnd > 0 && this.chapterEnd <= this.chapters) {
          end = this.chapterEnd;
        }
        if (start > end) {
          throw new Exception(
              "Start chapter $start is greater than the end chapter $end");
        }
        job.args.add("--chapters");
        job.args.add("$start-$end");

        output.add(job);
      }
    } else {
      final EncoderJob job = _prepareEncoderJob();
      output.add(job);
    }

    return output;
  }

  EncoderJob _prepareEncoderJob() {
    EncoderJob output = new EncoderJob()
      ..inputPath = this.fullPath
      ..args = _encoding.toProcessArgs();

    int count = streams
        .where((StreamData dt) => dt.type == StreamTypes.subtitle)
        .length;
    if (flipSubtitles && count >= 2) {
      List<int> subtitleOrder = <int>[2, 1];
      for (int i = 3; i <= count; i++) {
        subtitleOrder.add(i);
      }
      output.args.add('--subtitle');
      output.args.add(subtitleOrder.join(","));
      output.args.add('--subtitle-default=none');
    } else {
      output.args.addAll([
        '--all-subtitles',
        '--subtitle-lang-list',
        'eng',
        '--native-language',
        'en'
      ]);
    }

    if(this.audioLanguages.length==0) {
      output.args.add('--all-audio');
    } else {
      List<StreamData> allAudioStreams = this.audioStreams;
      List<StreamData> remainingAudioStreams = this.audioStreams;
      List<int> selectedStreams = <int>[];

      StreamData previousStream;
      for (String lang in this.audioLanguages) {
        previousStream = null;
        for (StreamData sd in remainingAudioStreams
            .where(
                (StreamData sd) =>
            sd.language == lang || lang == Language.All)
            .toList()) {
          remainingAudioStreams.remove(sd);

          if (detectHdSubAudioTrack && previousStream != null) {
            // This is intended to work with the MKV files outputted by MakeMKV.
            // If a title has a DTS HD Master track, it has a sub-track of a lower quality that gets copied as well.
            // Same goes for Dolby TrueHD.
            // Rather than continuing to deal with duplicate tracks, this attempts to detect and skip them.
            if ((sd.codec == "dts" &&
                previousStream.codec == sd.codec &&
                previousStream.profile == "DTS-HD MA" &&
                sd.profile == "DTS") ||
                (sd.codec == "ac3" && previousStream.codec == "truehd")) {
              previousStream = null;
              continue;
            }
          }
          selectedStreams.add(allAudioStreams.indexOf(sd) + 1);
          previousStream = sd;
        }
      }

      output.args.add("--audio");
      output.args.add(selectedStreams.join(","));
    }

    if(this.maxHeight!=-1) {
      output.args.add("--maxHeight ${this.maxHeight}");
    }
    
    return output;
  }

  Map toJson() => {
        'id': this.id,
        'path': this.path,
        'name': this.name,
        'status': status.toString().split(".")[1],
        'duration': duration,
        'size': size,
        'chapters': this.chapters,
        'type': type,
        'streams': streams.map((StreamData sd) => sd.toJson()).toList(),
        'progress': progress,
        'job_args': getEncoderJobs().map((EncoderJob ej) => ej.args.join(' ')).toList(),
      };

  void resetSettings() {
    this._encoding = new EncodingSettings();
    chapterSplit = 0;
    chapterStart = 0;
    chapterEnd = 0;
    flipSubtitles = false;
    detectHdSubAudioTrack = false;
    audioLanguages.clear();

  }
  void applySettings(Map data) {
    for (String key in data.keys) {
      switch (key) {
        case "chapter_start":
          this.chapterStart = int.parse(data[key].toString());
          break;
        case "chapter_end":
          this.chapterEnd = int.parse(data[key].toString());
          break;
        case "chapter_split":
          this.chapterSplit = int.parse(data[key].toString());
          break;
        case "chapter_splits":
          for(dynamic value in data[key]) {
            this.chapterSplits.add(int.parse(value.toString()));
          }
          break;
        case "subtitle_languages":
          //this = data[key]?.toString()?.toLowerCase() == "true";
          break;
        case "flip_subtitles":
          this.flipSubtitles = data[key]?.toString()?.toLowerCase() == "true";
          break;
        case "audio_languages":
          this.audioLanguages.clear();
          for(dynamic i in data[key]) {
            this.audioLanguages.add(i.toString());
          }
          break;
        case "detect_dts_duplicates":
        case "detect_hd_audio_substream":
          detectHdSubAudioTrack =
              data[key]?.toString()?.toLowerCase() == "true";
          break;
        case "files":
          break;
        case "max_height":
          this.maxHeight = int.parse(data[key].toString());
          break;
        default:
          _log.warning("Unknown setting: $key");
      }
    }
    _encoding.applySettings(data);

    if (data.containsKey("files") && data["files"].containsKey(this.name)) {
      applySettings(data["files"][this.name]);
    }
  }

}
