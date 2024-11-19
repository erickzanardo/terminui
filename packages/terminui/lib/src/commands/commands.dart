import 'package:args/args.dart';

abstract class TerminuiCommand<S> {
  ArgParser get parser => ArgParser();
  String get description;
  String get name;

  (String?, String) run(S subject, List<String> args) {
    final results = parser.parse(args);
    return execute(subject, results);
  }

  (String?, String) execute(S subject, ArgResults results);

  int? optionalIntResult(String key, ArgResults results) {
    if (results[key] != null) {
      return int.tryParse(results[key] as String);
    }
    return null;
  }
}
