import 'package:flutter/material.dart';

TimeOfDay parseTimeOfDay(String timeStr) {
  final parts = timeStr.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1].split(' ')[0]); // Handle AM/PM if present
  return TimeOfDay(hour: hour, minute: minute);
}

DateTime calculateCheckOutDate(
  DateTime checkInDate,
  TimeOfDay checkInTime,
  int numberOfNights,
  int numberOfDays,
) {
  DateTime checkInDateTime = DateTime(
    checkInDate.year,
    checkInDate.month,
    checkInDate.day,
    checkInTime.hour,
    checkInTime.minute,
  );

  DateTime finalCheckOutDateTime;

  if (numberOfNights > 0) {
    finalCheckOutDateTime = checkInDateTime.add(Duration(days: numberOfNights));
    finalCheckOutDateTime = DateTime(
      finalCheckOutDateTime.year,
      finalCheckOutDateTime.month,
      finalCheckOutDateTime.day,
      6, // Default 6 AM checkout for night stays
      0,
    );
  } else if (numberOfDays > 0) {
    finalCheckOutDateTime = checkInDateTime.add(Duration(days: numberOfDays - 1)); // -1 because the first day is 'today'
    finalCheckOutDateTime = DateTime(
      finalCheckOutDateTime.year,
      finalCheckOutDateTime.month,
      finalCheckOutDateTime.day,
      18, // 6 PM checkout for day-only bookings
      0,
    );
  } else {
    return checkInDateTime; // Should not happen if validation prevents 0 nights and 0 days
  }
  return finalCheckOutDateTime;
}

TimeOfDay calculateCheckOutTime(
  DateTime checkInDate,
  TimeOfDay checkInTime,
  int numberOfNights,
  int numberOfDays,
) {
  DateTime checkInDateTime = DateTime(
    checkInDate.year,
    checkInDate.month,
    checkInDate.day,
    checkInTime.hour,
    checkInTime.minute,
  );

  DateTime finalCheckOutDateTime;

  if (numberOfNights > 0) {
    finalCheckOutDateTime = checkInDateTime.add(Duration(days: numberOfNights));
    finalCheckOutDateTime = DateTime(
      finalCheckOutDateTime.year,
      finalCheckOutDateTime.month,
      finalCheckOutDateTime.day,
      6, // Default 6 AM checkout for night stays
      0,
    );
  } else if (numberOfDays > 0) {
    finalCheckOutDateTime = checkInDateTime.add(Duration(days: numberOfDays - 1)); // -1 because the first day is 'today'
    finalCheckOutDateTime = DateTime(
      finalCheckOutDateTime.year,
      finalCheckOutDateTime.month,
      finalCheckOutDateTime.day,
      18, // 6 PM checkout for day-only bookings
      0,
    );
  } else {
    return checkInTime; // Should not happen if validation prevents 0 nights and 0 days
  }
  return TimeOfDay.fromDateTime(finalCheckOutDateTime);
}

