/// Returns the display label for a time-slot index.
/// Slots 0–8  → "1"–"9"
/// Slots 9–11 → "a", "b", "c"
String slotLabel(int index) {
  if (index < 9) return '${index + 1}';
  return ['a', 'b', 'c'][index - 9];
}
 