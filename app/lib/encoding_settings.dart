import 'enums/encoders.dart';
import 'enums/encoder_preset.dart';

class EncodingSettings {
  Encoders encoder = Encoders.x265_10bit;
  EncoderPreset preset = EncoderPreset.slow;

  bool twoPass = true;

  int width = 0, height = 0, quality = 18;

  EncodingSettings();

  EncodingSettings.fromJson(Map data) {
    applySettings(data);
  }

  void applySettings(Map data) {
    for (String key in data.keys) {
      switch (key) {
        case "encoder":
          encoder = parseEncoder(data[key]);
          break;
        case "preset":
          preset = parseEncoderPreset(data[key]);
          break;
        case "quality":
          quality = int.parse(data[key].toString());
          break;
        case "two_pass":
          twoPass = data[key].toString()=="true";
          break;
        case "height":
          height = int.parse(data[key].toString());
          break;
        case "width":
          width = int.parse(data[key].toString());
          break;

      }
    }
  }

  Map toJson() {
    Map<String, dynamic> output = <String, dynamic>{};
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
      this.preset.toString().split(".")[1],
      '--encoder-profile',
      'auto',
      '--quality',
      quality.toString(),
      '--vfr',
      '--aencoder',
      'opus',
//    'copy',
//    '--audio-copy-mask',
//    'aac,mp3',
//    '--audio-fallback',
//    'opus',
      '--mixdown',
      '5_2_lfe',
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
    ]);

    if (twoPass) {
      output.add('--two-pass');
    }

    if (width > 0) {
      output.addAll(["--width", width.toString()]);
    }
    if (height > 0) {
      output.addAll(["--height", height.toString()]);
    }

    return output;
  }
}

class AudioTrackEncodingSettings {
  Encoders encoder;
}
