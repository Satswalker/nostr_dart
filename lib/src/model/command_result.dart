/// A command result returned in response to publishing an event.
class CommandResult {
  /// The raw command result message as a JSON array.
  final List<dynamic> _result;

  /// The ID of the event that the [CommandResult] refers to.
  final String id;

  /// Whether the event was successfully published.
  final bool success;

  /// Additional information as to why the command succeeded or failed.
  final String message;

  CommandResult(List<dynamic> result)
      : _result = result,
        id = result[1],
        success = result[2],
        message = result[3];

  @override

  /// Returns the raw command result message as a [String].
  String toString() {
    return _result.toString();
  }
}
