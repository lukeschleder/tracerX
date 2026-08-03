import 'dart:io' as io;

/// Runtime environment captured when a trace session starts.
class SystemInfo {
  /// Creates a system info snapshot.
  const SystemInfo({
    required this.os,
    required this.osVersion,
    required this.pid,
    required this.dartVersion,
  });

  final String os;
  final String osVersion;
  final int pid;
  final String dartVersion;

  /// Captures the current process environment.
  factory SystemInfo.current() => SystemInfo(
        os: io.Platform.operatingSystem,
        osVersion: io.Platform.operatingSystemVersion,
        pid: io.pid,
        dartVersion: io.Platform.version,
      );

  /// JSON representation for [TracerTrace] export.
  Map<String, dynamic> toJson() => {
        'os': os,
        'osVersion': osVersion,
        'pid': pid,
        'dartVersion': dartVersion,
      };

  /// Restores from JSON produced by [toJson].
  factory SystemInfo.fromJson(Map<String, dynamic> json) => SystemInfo(
        os: json['os'] as String,
        osVersion: json['osVersion'] as String,
        pid: json['pid'] as int,
        dartVersion: json['dartVersion'] as String,
      );
}
