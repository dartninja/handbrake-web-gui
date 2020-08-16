enum CopyableAudioCodecs {
  aac,
  ac3,
  eac3,
  truehd,
  dts,
  dtshd,
  mp3,
  flac
}

CopyableAudioCodecs parseCopyableAudioCodec(String input) => CopyableAudioCodecs.values
    .firstWhere((CopyableAudioCodecs e) => e.toString().split(".")[1] == input);

List<String> getCopyableAudioCodecs() => new List<String>.from(
    CopyableAudioCodecs.values.map((CopyableAudioCodecs e) => e.toString().split(".")[1]),
    growable: false);
