enum Encoders {
  x264,
  x264_10bit,
  x265,
  x265_10bit,
  x265_12bit,
  mpeg4,
  mpeg2,
  VP8,
  VP9,
  theora
}

Encoders parseEncoder(String input) => Encoders.values.firstWhere((Encoders e) => e.toString().split(".")[1]==input);

List<String> getEncoders() => new List<String>.from(Encoders.values.map((Encoders e) => e.toString().split(".")[1]),  growable: false);