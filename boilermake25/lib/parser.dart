import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> fetchCalendarEvents(
  String accessToken,
  List<String> args,
) async {
  final url = Uri.parse(
    "https://www.googleapis.com/calendar/v3/calendars/primary/events",
  );

  final response = await http.get(
    url,
    headers: {"Authorization": "Bearer $accessToken"},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final events = data['items'] as List<dynamic>?;

    if (events == null || events.isEmpty) {
      return "No upcoming calendar events.";
    }

    return "Calendar Events:\n" +
        events.map((e) => "- ${e['summary']}").join("\n");
  } else {
    return "Failed to fetch calendar events: ${response.body}";
  }
}

Future<String> addCalendarEvent(String accessToken, List<String> args) async {
  if (args.isEmpty) return "Error: Missing event details.";

  final url = Uri.parse(
    "https://www.googleapis.com/calendar/v3/calendars/primary/events",
  );
  final body = jsonEncode({
    "summary": args.join(" "), // Event title
    "start": {"dateTime": "2025-02-23T10:00:00Z", "timeZone": "UTC"},
    "end": {"dateTime": "2025-02-23T11:00:00Z", "timeZone": "UTC"},
  });

  final response = await http.post(
    url,
    headers: {
      "Authorization": "Bearer $accessToken",
      "Content-Type": "application/json",
    },
    body: body,
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    return "Event added successfully.";
  } else {
    return "Failed to add event: ${response.body}";
  }
}

Future<String> fetchTasks(String accessToken, List<String> args) async {
  final url = Uri.parse(
    "https://www.googleapis.com/tasks/v1/lists/@default/tasks",
  );

  final response = await http.get(
    url,
    headers: {"Authorization": "Bearer $accessToken"},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final tasks = data['items'] as List<dynamic>?;

    if (tasks == null || tasks.isEmpty) {
      return "No tasks found.";
    }

    return "Tasks:\n" + tasks.map((t) => "- ${t['title']}").join("\n");
  } else {
    return "Failed to fetch tasks: ${response.body}";
  }
}

Future<String> addTask(String accessToken, List<String> args) async {
  if (args.isEmpty) return "Error: Missing task details.";

  final url = Uri.parse(
    "https://www.googleapis.com/tasks/v1/lists/@default/tasks",
  );
  final body = jsonEncode({
    "title": args.join(" "), // Task title
  });

  final response = await http.post(
    url,
    headers: {
      "Authorization": "Bearer $accessToken",
      "Content-Type": "application/json",
    },
    body: body,
  );

  if (response.statusCode == 200 || response.statusCode == 201) {
    return "Task added successfully.";
  } else {
    return "Failed to add task: ${response.body}";
  }
}

typedef FunctionHandler =
    Future<String> Function(String accessToken, List<String> args);

final Map<String, FunctionHandler> functionMap = {
  "#CAL READ": fetchCalendarEvents,
  "#CAL WRITE": addCalendarEvent,
  "#TODO READ": fetchTasks,
  "#TODO WRITE": addTask,
};

Future<String> parseCommand(String input, String accessToken) async {
  if (!input.contains("#")) {
    return "Invalid command format.";
  }

  if (functionMap.containsKey(input)) {
    return await functionMap[input]!(
      accessToken,
      args
    ); // Call function with token and args
  } else {
    return "Unknown command: $input";
  }
}