enum EncoderPreset { veryfast, slow }

EncoderPreset parseEncoderPreset(String input) => EncoderPreset.values
    .firstWhere((EncoderPreset e) => e.toString().split(".")[1] == input);
