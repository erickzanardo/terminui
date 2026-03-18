import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminui/src/controller.dart';
import 'package:terminui/terminui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TerminuiController<void> controller;
  late ScrollController scrollController;
  var closeCalled = false;

  TerminuiState state() => controller.state.value;

  setUp(() {
    closeCalled = false;
    scrollController = ScrollController();
    controller = TerminuiController<void>(
      subject: null,
      repository: MemoryTerminuiRepository(),
      scrollController: scrollController,
      onClose: () => closeCalled = true,
      commands: {},
    );
  });

  tearDown(() {
    scrollController.dispose();
  });

  KeyEvent keyDown(LogicalKeyboardKey key, {String? char}) {
    return KeyDownEvent(
      logicalKey: key,
      physicalKey: PhysicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
      character: char,
    );
  }

  KeyEvent keyUp(LogicalKeyboardKey key) {
    return KeyUpEvent(
      logicalKey: key,
      physicalKey: PhysicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    );
  }

  Set<LogicalKeyboardKey> noModifiers() => {};
  Set<LogicalKeyboardKey> ctrl() => {LogicalKeyboardKey.controlLeft};

  void type(String text) {
    for (final c in text.split('')) {
      LogicalKeyboardKey key;
      switch (c) {
        case ' ':
          key = LogicalKeyboardKey.space;
        default:
          key = LogicalKeyboardKey(c.codeUnitAt(0));
      }
      controller.handleKeyEvent(keyDown(key, char: c), noModifiers());
    }
  }

  group('TerminuiState.copyWith', () {
    test('preserves unset values', () {
      const original = TerminuiState(
        showHistory: true,
        commandHistoryIndex: 3,
        commandHistory: ['a', 'b'],
        history: ['x'],
        cmd: 'hello',
        cursorPosition: 2,
      );

      final copied = original.copyWith();

      expect(copied.showHistory, true);
      expect(copied.commandHistoryIndex, 3);
      expect(copied.commandHistory, ['a', 'b']);
      expect(copied.history, ['x']);
      expect(copied.cmd, 'hello');
      expect(copied.cursorPosition, 2);
    });
  });

  group('KeyUpEvent', () {
    test('is ignored and returns handled', () {
      type('abc');
      final before = state().cmd;
      final result = controller.handleKeyEvent(
        keyUp(LogicalKeyboardKey.keyA),
        noModifiers(),
      );
      expect(result, KeyEventResult.handled);
      expect(state().cmd, before);
    });
  });

  group('Escape', () {
    test('calls onClose when history not showing', () {
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.escape),
        noModifiers(),
      );
      expect(closeCalled, true);
    });
  });

  group('Character insertion', () {
    test('at end of text', () {
      type('abc');
      expect(state().cmd, 'abc');
      expect(state().cursorPosition, 3);
    });

    test('at beginning of text', () {
      type('bc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.keyA, char: 'a'),
        noModifiers(),
      );
      expect(state().cmd, 'abc');
      expect(state().cursorPosition, 1);
    });

    test('in middle of text', () {
      type('ac');
      // Move cursor left once to be between a and c
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.keyB, char: 'b'),
        noModifiers(),
      );
      expect(state().cmd, 'abc');
      expect(state().cursorPosition, 2);
    });
  });

  group('Arrow left/right', () {
    test('arrow left moves cursor', () {
      type('abc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        noModifiers(),
      );
      expect(state().cursorPosition, 2);
    });

    test('arrow right moves cursor', () {
      type('abc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowRight),
        noModifiers(),
      );
      expect(state().cursorPosition, 3);
    });

    test('arrow left clamps at 0', () {
      type('a');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        noModifiers(),
      );
      expect(state().cursorPosition, 0);
    });

    test('arrow right clamps at cmd.length', () {
      type('ab');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowRight),
        noModifiers(),
      );
      expect(state().cursorPosition, 2);
    });
  });

  group('Home/End', () {
    test('home moves to 0', () {
      type('hello');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      expect(state().cursorPosition, 0);
    });

    test('end moves to cmd.length', () {
      type('hello');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.end),
        noModifiers(),
      );
      expect(state().cursorPosition, 5);
    });
  });

  group('Ctrl+A / Ctrl+E', () {
    test('ctrl+a moves to beginning', () {
      type('hello');
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyA), ctrl());
      expect(state().cursorPosition, 0);
    });

    test('ctrl+e moves to end', () {
      type('hello');
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyA), ctrl());
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyE), ctrl());
      expect(state().cursorPosition, 5);
    });
  });

  group('Backspace', () {
    test('at end of text', () {
      type('abc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.backspace),
        noModifiers(),
      );
      expect(state().cmd, 'ab');
      expect(state().cursorPosition, 2);
    });

    test('in middle of text', () {
      type('abc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.backspace),
        noModifiers(),
      );
      expect(state().cmd, 'ac');
      expect(state().cursorPosition, 1);
    });

    test('at position 0 does nothing', () {
      type('abc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.backspace),
        noModifiers(),
      );
      expect(state().cmd, 'abc');
      expect(state().cursorPosition, 0);
    });
  });

  group('Delete key', () {
    test('at middle of text', () {
      type('abc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.delete),
        noModifiers(),
      );
      expect(state().cmd, 'bc');
      expect(state().cursorPosition, 0);
    });

    test('at end of text does nothing', () {
      type('abc');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.delete),
        noModifiers(),
      );
      expect(state().cmd, 'abc');
      expect(state().cursorPosition, 3);
    });
  });

  group('Ctrl+Left / Ctrl+Right word navigation', () {
    test('ctrl+left moves to previous word boundary', () {
      type('hello world foo');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        ctrl(),
      );
      expect(state().cursorPosition, 12); // before 'foo'
    });

    test('ctrl+left moves through multiple words', () {
      type('hello world foo');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        ctrl(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        ctrl(),
      );
      expect(state().cursorPosition, 6); // before 'world'
    });

    test('ctrl+left from beginning stays at 0', () {
      type('hello');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowLeft),
        ctrl(),
      );
      expect(state().cursorPosition, 0);
    });

    test('ctrl+right moves to next word boundary', () {
      type('hello world foo');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowRight),
        ctrl(),
      );
      expect(state().cursorPosition, 6); // after 'hello '
    });

    test('ctrl+right from end stays at end', () {
      type('hello');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowRight),
        ctrl(),
      );
      expect(state().cursorPosition, 5);
    });
  });

  group('Ctrl+Backspace / Ctrl+W word deletion', () {
    test('ctrl+backspace deletes previous word', () {
      type('hello world');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.backspace),
        ctrl(),
      );
      expect(state().cmd, 'hello ');
      expect(state().cursorPosition, 6);
    });

    test('ctrl+w deletes previous word', () {
      type('hello world');
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyW), ctrl());
      expect(state().cmd, 'hello ');
      expect(state().cursorPosition, 6);
    });

    test('ctrl+backspace at beginning does nothing', () {
      type('hello');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.backspace),
        ctrl(),
      );
      expect(state().cmd, 'hello');
      expect(state().cursorPosition, 0);
    });
  });

  group('Ctrl+Delete forward word deletion', () {
    test('deletes from cursor to next word boundary', () {
      type('hello world foo');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.home),
        noModifiers(),
      );
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.delete),
        ctrl(),
      );
      expect(state().cmd, 'world foo');
      expect(state().cursorPosition, 0);
    });

    test('at end does nothing', () {
      type('hello');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.delete),
        ctrl(),
      );
      expect(state().cmd, 'hello');
      expect(state().cursorPosition, 5);
    });
  });

  group('Ctrl+K kill to end of line', () {
    test('deletes everything after cursor', () {
      type('hello world');
      // Move to position 5
      for (var i = 0; i < 6; i++) {
        controller.handleKeyEvent(
          keyDown(LogicalKeyboardKey.arrowLeft),
          noModifiers(),
        );
      }
      expect(state().cursorPosition, 5);
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyK), ctrl());
      expect(state().cmd, 'hello');
      expect(state().cursorPosition, 5);
    });
  });

  group('Ctrl+U kill to beginning', () {
    test('deletes everything before cursor', () {
      type('hello world');
      // Move to position 5
      for (var i = 0; i < 6; i++) {
        controller.handleKeyEvent(
          keyDown(LogicalKeyboardKey.arrowLeft),
          noModifiers(),
        );
      }
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyU), ctrl());
      expect(state().cmd, ' world');
      expect(state().cursorPosition, 0);
    });
  });

  group('Ctrl+C', () {
    test('kills to beginning when not showing history', () {
      type('hello world');
      for (var i = 0; i < 6; i++) {
        controller.handleKeyEvent(
          keyDown(LogicalKeyboardKey.arrowLeft),
          noModifiers(),
        );
      }
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyC), ctrl());
      expect(state().cmd, ' world');
      expect(state().cursorPosition, 0);
    });

    test('closes history when showing history', () {
      // Set up with history
      controller = TerminuiController<void>(
        subject: null,
        repository: MemoryTerminuiRepository(),
        scrollController: scrollController,
        onClose: () => closeCalled = true,
        commands: {},
        state: const TerminuiState(
          showHistory: true,
          commandHistory: ['test'],
        ),
      );

      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyC), ctrl());
      expect(state().showHistory, false);
    });
  });

  group('Ctrl+L', () {
    test('clears screen and input', () {
      type('hello');
      controller.handleKeyEvent(keyDown(LogicalKeyboardKey.keyL), ctrl());
      expect(state().history, isEmpty);
      expect(state().cmd, '');
      expect(state().cursorPosition, 0);
    });
  });

  group('Enter', () {
    test('resets cmd and cursorPosition to 0', () {
      type('clear');
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.enter),
        noModifiers(),
      );
      expect(state().cmd, '');
      expect(state().cursorPosition, 0);
    });

    test('with empty input does nothing', () {
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.enter),
        noModifiers(),
      );
      expect(state().cmd, '');
      expect(state().cursorPosition, 0);
    });
  });

  group('History selection', () {
    test('sets cursorPosition to end of selected command', () {
      controller = TerminuiController<void>(
        subject: null,
        repository: MemoryTerminuiRepository(),
        scrollController: scrollController,
        onClose: () => closeCalled = true,
        commands: {},
        state: const TerminuiState(
          showHistory: true,
          commandHistory: ['hello world'],
        ),
      );

      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.enter),
        noModifiers(),
      );
      expect(state().cmd, 'hello world');
      expect(state().cursorPosition, 11);
      expect(state().showHistory, false);
    });
  });

  group('Arrow Up to open history', () {
    test('only opens history if commandHistory is not empty', () {
      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowUp),
        noModifiers(),
      );
      expect(state().showHistory, false);
    });

    test('opens history when commandHistory is not empty', () {
      controller = TerminuiController<void>(
        subject: null,
        repository: MemoryTerminuiRepository(),
        scrollController: scrollController,
        onClose: () {
          closeCalled = true;
        },
        commands: {},
        state: const TerminuiState(
          commandHistory: ['test'],
        ),
      );

      controller.handleKeyEvent(
        keyDown(LogicalKeyboardKey.arrowUp),
        noModifiers(),
      );
      expect(state().showHistory, true);
    });
  });
}
