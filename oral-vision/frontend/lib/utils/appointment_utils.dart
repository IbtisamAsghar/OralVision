class AppointmentUtils {
  static const List<String> allTimeSlots = [
    '09:00 AM', '09:30 AM', '10:00 AM', '10:30 AM',
    '11:00 AM', '11:30 AM', '12:00 PM', '02:00 PM',
    '02:30 PM', '03:00 PM', '03:30 PM', '04:00 PM',
    '04:30 PM', '05:00 PM',
  ];

  static DateTime? parseSlot(DateTime date, String slot) {
    final parts = slot.split(' ');
    if (parts.length != 2) return null;
    final timeParts = parts[0].split(':');
    if (timeParts.length != 2) return null;
    var hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;
    final period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static List<String> availableSlots({
    required DateTime? selectedDate,
    required Set<String> bookedSlots,
    DateTime? now,
  }) {
    if (selectedDate == null) return [];
    final current = now ?? DateTime.now();
    final isToday = selectedDate.year == current.year &&
        selectedDate.month == current.month &&
        selectedDate.day == current.day;
    return allTimeSlots.where((slot) {
      if (bookedSlots.contains(slot)) return false;
      if (!isToday) return true;
      final slotTime = parseSlot(selectedDate, slot);
      if (slotTime == null) return false;
      return slotTime.isAfter(current);
    }).toList();
  }

  static List<Map<String, dynamic>> allSlotsWithStatus({
    required DateTime? selectedDate,
    required Set<String> bookedSlots,
    DateTime? now,
  }) {
    if (selectedDate == null) return [];
    final current = now ?? DateTime.now();
    final isToday = selectedDate.year == current.year &&
        selectedDate.month == current.month &&
        selectedDate.day == current.day;
    final result = <Map<String, dynamic>>[];
    for (final slot in allTimeSlots) {
      if (isToday) {
        final slotTime = parseSlot(selectedDate, slot);
        if (slotTime == null || !slotTime.isAfter(current)) continue;
      }
      result.add({'time': slot, 'booked': bookedSlots.contains(slot)});
    }
    return result;
  }
}
