enum Mixdowns {
  mono,
  left_only,
  right_only,
  stereo,
  dpl1,
  dpl2,
  s5point1,
  s6point1,
  s7point1,
  s5_2_lfe,
}
Mixdowns parseMixdown(String input) => Mixdowns.values
    .firstWhere((Mixdowns e) => e.toString().split(".")[1] == input);

List<String> getMixdowns() => new List<String>.from(
    Mixdowns.values.map((Mixdowns e) => e.toString().split(".")[1]),
    growable: false);
