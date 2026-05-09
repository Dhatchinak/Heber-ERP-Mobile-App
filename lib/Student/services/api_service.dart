import 'dart:convert';
import 'package:bhc_erp/Student/screens/academic_calendar.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://117.232.64.75/api";

  // Fetch academic calendar data
  static Future<List<CalendarEvent>> fetchAcademicCalendar() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/academic_calander'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseCalendarEvents(data);
      } else {
        throw Exception(
          'Failed to load calendar data. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('API Error: $e');
      throw Exception('Error fetching calendar: $e');
    }
  }

  static List<CalendarEvent> _parseCalendarEvents(dynamic data) {
    List<CalendarEvent> events = [];

    try {
      // Handle different possible API response structures
      if (data is Map && data.containsKey('events')) {
        // If response has 'events' key
        final eventsData = data['events'];
        if (eventsData is List) {
          for (var event in eventsData) {
            final calendarEvent = _parseEvent(event);
            if (calendarEvent != null) {
              events.add(calendarEvent);
            }
          }
        }
      } else if (data is List) {
        // If response is directly a list
        for (var event in data) {
          final calendarEvent = _parseEvent(event);
          if (calendarEvent != null) {
            events.add(calendarEvent);
          }
        }
      } else if (data is Map) {
        // If response is a single event object
        final calendarEvent = _parseEvent(data);
        if (calendarEvent != null) {
          events.add(calendarEvent);
        }
      }
    } catch (e) {
      print('Error parsing events: $e');
    }

    // If no events found in API response, use mock data as fallback
    if (events.isEmpty) {
      print('No events found in API response, using mock data');
      events = _getMockEvents();
    }

    return events;
  }

  static CalendarEvent? _parseEvent(dynamic event) {
    try {
      // Adjust these field names based on your actual API response
      final title =
          event['title'] ??
          event['event_name'] ??
          event['name'] ??
          'Unknown Event';
      final startDateStr =
          event['start_date'] ?? event['startDate'] ?? event['date'];
      final endDateStr = event['end_date'] ?? event['endDate'] ?? event['date'];
      final typeStr = event['type'] ?? event['event_type'] ?? 'academic';

      if (startDateStr == null) {
        print('Skipping event with no start date: $title');
        return null;
      }

      final startDate = DateTime.parse(startDateStr);
      final endDate = endDateStr != null
          ? DateTime.parse(endDateStr)
          : startDate;
      final type = _parseEventType(typeStr);

      return CalendarEvent(
        title: title.toString(),
        startDate: startDate,
        endDate: endDate,
        type: type,
      );
    } catch (e) {
      print('Error parsing individual event: $e');
      return null;
    }
  }

  static EventType _parseEventType(String type) {
    final typeLower = type.toLowerCase();

    if (typeLower.contains('exam') || typeLower.contains('test')) {
      return EventType.exam;
    } else if (typeLower.contains('holiday') || typeLower.contains('pooja')) {
      return EventType.holiday;
    } else {
      return EventType.academic;
    }
  }

  // Fallback mock data if API fails
  static List<CalendarEvent> _getMockEvents() {
    return [
      CalendarEvent(
        title: "Release of Internal Marks",
        startDate: DateTime(2025, 10, 10),
        endDate: DateTime(2025, 10, 25),
        type: EventType.academic,
      ),
      CalendarEvent(
        title: "Internal Test II",
        startDate: DateTime(2025, 10, 3),
        endDate: DateTime(2025, 10, 3),
        type: EventType.exam,
      ),
      CalendarEvent(
        title: "External Test II",
        startDate: DateTime(2025, 10, 4),
        endDate: DateTime(2025, 10, 4),
        type: EventType.exam,
      ),
      CalendarEvent(
        title: "End Semester Examinations",
        startDate: DateTime(2025, 10, 6),
        endDate: DateTime(2025, 10, 11),
        type: EventType.exam,
      ),
      CalendarEvent(
        title: "Ayutha Pooja",
        startDate: DateTime(2025, 10, 1),
        endDate: DateTime(2025, 10, 1),
        type: EventType.holiday,
      ),
      CalendarEvent(
        title: "Vijaya Dasami / Gandhi Jayanthi",
        startDate: DateTime(2025, 10, 2),
        endDate: DateTime(2025, 10, 2),
        type: EventType.holiday,
      ),
      CalendarEvent(
        title: "Saturday Holiday",
        startDate: DateTime(2025, 10, 4),
        endDate: DateTime(2025, 10, 4),
        type: EventType.holiday,
      ),
      CalendarEvent(
        title: "Saturday Holiday",
        startDate: DateTime(2025, 10, 11),
        endDate: DateTime(2025, 10, 11),
        type: EventType.holiday,
      ),
      CalendarEvent(
        title: "Saturday Holiday",
        startDate: DateTime(2025, 10, 18),
        endDate: DateTime(2025, 10, 18),
        type: EventType.holiday,
      ),
      CalendarEvent(
        title: "Saturday Holiday",
        startDate: DateTime(2025, 10, 25),
        endDate: DateTime(2025, 10, 25),
        type: EventType.holiday,
      ),
    ];
  }
}
