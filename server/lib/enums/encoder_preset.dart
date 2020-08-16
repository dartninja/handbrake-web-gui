enum EncoderPreset {
  ultrafast,
  superfast,
  veryfast,
  faster,
  fast,
  medium,
  slow,
  slower,
  veryslow,
  placebo,
}

EncoderPreset parseEncoderPreset(String input) => EncoderPreset.values
    .firstWhere((EncoderPreset e) => e.toString().split(".")[1] == input);
