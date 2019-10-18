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
//
//enum Mixdown {
//  mono,
//  left_only,
//  right_only,
//  stereo,
//  dpl1,
//  dpl2,
//  5point1,
//  6point1,
//  7point1,
//  5_2_lfe,
//}
Encoders parseEncoder(String input) => Encoders.values
    .firstWhere((Encoders e) => e.toString().split(".")[1] == input);

List<String> getEncoders() => new List<String>.from(
    Encoders.values.map((Encoders e) => e.toString().split(".")[1]),
    growable: false);
