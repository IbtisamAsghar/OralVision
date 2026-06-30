/// Formats chatbot responses for Flutter Text widgets (no markdown package needed).
class ChatFormatter {
  static String format(String raw) {
    var text = raw;
    text = text.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAll('•', '  •');
    return text.trim();
  }
}
