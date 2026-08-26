enum LogType { ok, error, info }

/// A single entry in the dashboard's activity history.
class ActivityLog {
  const ActivityLog(this.title, this.detail, this.time, this.type);

  final String title;
  final String detail;
  final DateTime time;
  final LogType type;
}
