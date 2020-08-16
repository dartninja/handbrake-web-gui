enum AudioEncoders {
  none,
ca_aac,
ca_haac,
ac3,
eac3,
mp3,
vorbis,
flac16,
flac24,
opus,
copy,
}

AudioEncoders parseAudioEncoder(String input) => AudioEncoders.values
    .firstWhere((AudioEncoders e) => e.toString().split(".")[1] == input);

List<String> getAudioEncoders() => new List<String>.from(
    AudioEncoders.values.map((AudioEncoders e) => e.toString().split(".")[1]),
    growable: false);
