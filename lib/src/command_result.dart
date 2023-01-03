class CommandResult {
  final String id;
  final bool result;
  final String message;

  bool get success => result;

  CommandResult._(
      {required this.id, required this.result, required this.message});

  factory CommandResult.parse(List<dynamic> rawMessage) {
    return CommandResult._(
        id: rawMessage[1], result: rawMessage[2], message: rawMessage[3]);
  }
}
