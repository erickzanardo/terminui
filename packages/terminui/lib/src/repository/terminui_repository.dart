/// A repository to persist and read history of commands.
abstract class TerminuiRepository {
  const TerminuiRepository();

  Future<void> addToCommandHistory(String command);
  Future<List<String>> listCommandHistory();
}
