import 'dart:io' as io;

/// Runtime environment captured when a trace session starts.
class SystemInfo {
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

  factory SystemInfo.current() => SystemInfo(
        os: io.Platform.operatingSystem,
        osVersion: io.Platform.operatingSystemVersion,
        pid: io.pid,
        dartVersion: io.Platform.version,
      );

  Map<String, dynamic> toJson() => {
        'os': os,
        'osVersion': osVersion,
        'pid': pid,
        'dartVersion': dartVersion,
      };

  factory SystemInfo.fromJson(Map<String, dynamic> json) => SystemInfo(
        os: json['os'] as String,
        osVersion: json['osVersion'] as String,
        pid: json['pid'] as int,
        dartVersion: json['dartVersion'] as String,
      );
}
