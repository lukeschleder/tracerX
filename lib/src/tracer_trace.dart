import 'dart:convert';
import 'dart:io';

import 'system_info.dart';
import 'trace_event.dart';

/// Structured export of a complete recorded trace session.
class TracerTrace {
  const TracerTrace({
    required this.sessionName,
    required this.startedAt,
    required this.systemInfo,
    required this.events,
    this.endedAt,
  });

  final String sessionName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SystemInfo systemInfo;
  final List<TraceEvent> events;

  Map<String, dynamic> toJson() => {
        'sessionName': sessionName,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
        'systemInfo': systemInfo.toJson(),
        'events': events.map((e) => e.toJson()).toList(),
      };

  String toJsonString({bool pretty = false}) {
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toJson());
    }
    return jsonEncode(toJson());
  }

  factory TracerTrace.fromJson(Map<String, dynamic> json) => TracerTrace(
        sessionName: json['sessionName'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
        endedAt: json['endedAt'] != null
            ? DateTime.parse(json['endedAt'] as String).toLocal()
            : null,
        systemInfo:
            SystemInfo.fromJson(json['systemInfo'] as Map<String, dynamic>),
        events: (json['events'] as List)
            .map((e) => TraceEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory TracerTrace.fromJsonString(String source) =>
      TracerTrace.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory TracerTrace.fromFile(String path) =>
      TracerTrace.fromJsonString(File(path).readAsStringSync());

  Future<void> saveToFile(String path) async {
    await File(path).writeAsString(toJsonString(pretty: true));
  }
}
