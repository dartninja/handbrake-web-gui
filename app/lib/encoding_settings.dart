import 'enums/encoders.dart';

class EncodingSettings {
  Encoders encoder = Encoders.x265_10bit;

  EncodingSettings();

  EncodingSettings.fromJson(Map data) {
    encoder = parseEncoder(data["encoder"]);
  }

  Map toJson() {
    Map<String, dynamic> output = <String,dynamic>{};
    output["encoder"] = encoder.toString().split(".")[1];

    return output;
  }

  String toString() => toProcessArgs().join(" ");

  List<String> toProcessArgs() {
    List<String> output = <String>[];

    output.addAll([
    '--min-duration',
    '0',
    '--format',
    'av_mkv',
    '--markers',
    '--encoder',
    this.encoder.toString().split(".")[1],
    '--encoder-preset',
    'slow',
    '--encoder-profile',
    'auto',
    '--quality',
    '18',
    '--two-pass',
    '--vfr',
    '--audio-lang-list',
    'jpn,eng,und',
    '--all-audio',
    '--aencoder',
    'copy',
    '--audio-copy-mask',
    'aac,mp3',
    '--audio-fallback',
    'aac',
    '--aq',
    '8',
    '--auto-anamorphic',
    '--no-hqdn3d',
    '--no-nlmeans',
    '--no-unsharp',
    '--no-lapsharp',
    '--no-deblock',
    '--comb-detect',
    '--decomb',
    '--detelecine',
    '--subtitle-lang-list',
    'eng',
    '--all-subtitles',
    '--native-language',
    'en']);


    return output;
  }

}
