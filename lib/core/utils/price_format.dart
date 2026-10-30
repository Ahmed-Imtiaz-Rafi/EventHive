/// Price formatting shared by every screen that shows money.
/// '500 BDT'. Whole amounts show no decimals; amounts with paisa show
/// two ('500.50 BDT'). The schema stores prices as NUMERIC(10,2).
String formatBdt(num amount) {
  final isWhole = amount == amount.roundToDouble();
  final text = isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  return '$text BDT';
}