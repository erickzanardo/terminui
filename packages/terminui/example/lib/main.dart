import 'package:flutter/material.dart';
import 'package:terminui/terminui.dart';

class MediaQueryWidthCommand extends TerminuiCommand<BuildContext> {
  @override
  String get description => 'Prints the width of the media query.';

  @override
  String get name => 'w';

  @override
  (String?, String) execute(BuildContext subject, _) {
    final width = MediaQuery.of(subject).size.width;

    return (null, 'Width: $width');
  }
}

class MediaQueryHeightCommand extends TerminuiCommand<BuildContext> {
  @override
  String get description => 'Prints the height of the media query.';

  @override
  String get name => 'h';

  @override
  (String?, String) execute(BuildContext subject, _) {
    final height = MediaQuery.of(subject).size.height;

    return (null, 'Height: $height');
  }
}

void main() {
  runApp(const MaterialApp(home: MyGameApp()));
}

class MyGameApp extends StatefulWidget {
  const MyGameApp({super.key});

  @override
  State<MyGameApp> createState() => _MyGameAppState();
}

class _MyGameAppState extends State<MyGameApp> {
  late final FocusNode _node;
  late final KeyboardEventEmitter _keyboardEventEmitter;

  @override
  void initState() {
    super.initState();

    _node = FocusNode()..requestFocus();

    _keyboardEventEmitter = KeyboardEventEmitter();
    _node.onKeyEvent = (_, event) {
      _keyboardEventEmitter.emit(event);

      return KeyEventResult.handled;
    };
  }

  @override
  void dispose() {
    super.dispose();

    _node.dispose();
    _keyboardEventEmitter.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _node,
        child: Builder(
          builder: (context) {
            return TerminuiView<BuildContext>(
              onClose: () {},
              commands: [
                MediaQueryWidthCommand(),
                MediaQueryHeightCommand(),
              ],
              subject: context,
              keyboardEventEmitter: _keyboardEventEmitter,
            );
          },
        ),
      ),
    );
  }
}
