import 'package:terminui/terminui.dart';

/// An implementation of a [TerminuiRepository] that stores the command history
/// in memory.
class MemoryTerminuiRepository extends TerminuiRepository {
  MemoryTerminuiRepository({
    List<String>? commands,
  }) : _commands = commands ?? <String>[];

  final List<String> _commands;

  @override
  Future<void> addToCommandHistory(String command) async {
    _commands.add(command);
  }

  @override
  Future<List<String>> listCommandHistory() async {
    return _commands;
  }
}
