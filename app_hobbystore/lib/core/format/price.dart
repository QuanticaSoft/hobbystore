final _thousands = RegExp(r'\B(?=(\d{3})+(?!\d))');

/// Precio en bolivianos con el formato local: "Bs 3.480" o "Bs 1.250,50".
String formatBob(double amount) {
  final cents = (amount * 100).round();
  final whole = (cents ~/ 100).toString().replaceAll(_thousands, '.');
  final fraction = cents % 100;
  return fraction == 0
      ? 'Bs $whole'
      : 'Bs $whole,${fraction.toString().padLeft(2, '0')}';
}
