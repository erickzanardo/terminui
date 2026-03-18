import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terminui/terminui.dart';

class TerminuiState {
  const TerminuiState({
    this.showHistory = false,
    this.commandHistoryIndex = 0,
    this.commandHistory = const [],
    this.history = const [],
    this.cmd = '',
    this.cursorPosition = 0,
  });

  final bool showHistory;
  final int commandHistoryIndex;
  final List<String> commandHistory;
  final List<String> history;
  final String cmd;
  final int cursorPosition;

  TerminuiState copyWith({
    bool? showHistory,
    int? commandHistoryIndex,
    List<String>? commandHistory,
    List<String>? history,
    String? cmd,
    int? cursorPosition,
  }) {
    return TerminuiState(
      showHistory: showHistory ?? this.showHistory,
      commandHistoryIndex: commandHistoryIndex ?? this.commandHistoryIndex,
      commandHistory: commandHistory ?? this.commandHistory,
      history: history ?? this.history,
      cmd: cmd ?? this.cmd,
      cursorPosition: cursorPosition ?? this.cursorPosition,
    );
  }
}

class TerminuiController<S> {
  TerminuiController({
    required this.subject,
    required this.repository,
    required this.scrollController,
    required this.onClose,
    required this.commands,
    TerminuiState state = const TerminuiState(),
  }) : state = ValueNotifier(state);

  final S subject;
  final ValueNotifier<TerminuiState> state;
  final TerminuiRepository repository;
  final VoidCallback onClose;
  final ScrollController scrollController;
  final Map<String, TerminuiCommand> commands;

  Future<void> init() async {
    final history = await repository.listCommandHistory();
    state.value = state.value.copyWith(history: history);
  }

  int _previousWordBoundary(String text, int position) {
    var pos = position;
    // Skip whitespace going left
    while (pos > 0 && text[pos - 1] == ' ') {
      pos--;
    }
    // Skip non-whitespace going left
    while (pos > 0 && text[pos - 1] != ' ') {
      pos--;
    }
    return pos;
  }

  int _nextWordBoundary(String text, int position) {
    var pos = position;
    // Skip non-whitespace going right
    while (pos < text.length && text[pos] != ' ') {
      pos++;
    }
    // Skip whitespace going right
    while (pos < text.length && text[pos] == ' ') {
      pos++;
    }
    return pos;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  KeyEventResult _executeCommand() {
    final cmd = state.value.cmd;
    final split = cmd.split(' ').where((e) => e.isNotEmpty);

    if (split.isEmpty) {
      return KeyEventResult.handled;
    }

    if (split.first == 'clear') {
      state.value = state.value.copyWith(
        history: [],
        cmd: '',
        cursorPosition: 0,
      );
      return KeyEventResult.handled;
    }

    if (split.first == 'help') {
      final output = commands.entries.fold('', (previous, entry) {
        final help = '${entry.key} - ${entry.value.description}'
            '${entry.value.parser.usage}';

        return '$previous\n$help';
      });

      state.value = state.value.copyWith(
        history: [...state.value.history, output],
        cmd: '',
        cursorPosition: 0,
      );
      return KeyEventResult.handled;
    }

    final originalCommand = cmd;
    state.value = state.value.copyWith(
      history: [...state.value.history, cmd],
      cmd: '',
      cursorPosition: 0,
    );

    final command = commands[split.first];

    if (command == null) {
      state.value = state.value.copyWith(
        history: [...state.value.history, 'Command not found'],
      );
    } else {
      repository.addToCommandHistory(originalCommand);
      state.value = state.value.copyWith(
        commandHistory: [...state.value.commandHistory, originalCommand],
      );
      final result = command.run(subject, split.skip(1).toList());

      if (result.$1 != null) {
        state.value = state.value.copyWith(
          history: [...state.value.history, ...result.$1!.split('\n')],
        );
      } else if (result.$2.isNotEmpty) {
        state.value = state.value.copyWith(
          history: [...state.value.history, ...result.$2.split('\n')],
        );
      }
    }

    _scrollToBottom();
    return KeyEventResult.handled;
  }

  KeyEventResult handleKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyUpEvent) {
      return KeyEventResult.handled;
    }

    final isCtrl = keysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        keysPressed.contains(LogicalKeyboardKey.controlRight);

    final char = event.character;
    final cmd = state.value.cmd;
    final cursorPos = state.value.cursorPosition;
    final showHistory = state.value.showHistory;
    final hasHistory = showHistory && state.value.commandHistory.isNotEmpty;

    if (event.logicalKey == LogicalKeyboardKey.escape && !showHistory) {
      onClose();
    } else if (event.logicalKey == LogicalKeyboardKey.escape && showHistory) {
      state.value = state.value.copyWith(showHistory: false);
    } else if (event.logicalKey == LogicalKeyboardKey.keyC && isCtrl) {
      if (showHistory) {
        state.value = state.value.copyWith(showHistory: false);
      } else {
        state.value = state.value.copyWith(
          cmd: cmd.substring(cursorPos),
          cursorPosition: 0,
        );
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyL && isCtrl) {
      state.value = state.value.copyWith(
        history: [],
        cmd: '',
        cursorPosition: 0,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.keyK && isCtrl) {
      state.value = state.value.copyWith(
        cmd: cmd.substring(0, cursorPos),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.keyU && isCtrl) {
      state.value = state.value.copyWith(
        cmd: cmd.substring(cursorPos),
        cursorPosition: 0,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.keyA && isCtrl) {
      state.value = state.value.copyWith(cursorPosition: 0);
    } else if (event.logicalKey == LogicalKeyboardKey.keyE && isCtrl) {
      state.value = state.value.copyWith(cursorPosition: cmd.length);
    } else if (event.logicalKey == LogicalKeyboardKey.keyW && isCtrl) {
      final boundary = _previousWordBoundary(cmd, cursorPos);
      state.value = state.value.copyWith(
        cmd: cmd.substring(0, boundary) + cmd.substring(cursorPos),
        cursorPosition: boundary,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && !showHistory) {
      if (state.value.commandHistory.isNotEmpty) {
        state.value = state.value.copyWith(
          showHistory: true,
          commandHistoryIndex: state.value.commandHistory.length - 1,
        );
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter && showHistory) {
      final selectedCmd = hasHistory
          ? state.value.commandHistory[state.value.commandHistoryIndex]
          : state.value.cmd;
      state.value = state.value.copyWith(
        cmd: selectedCmd,
        cursorPosition: selectedCmd.length,
        showHistory: false,
      );
    } else if ((event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) &&
        hasHistory) {
      final delta = event.logicalKey == LogicalKeyboardKey.arrowUp ? -1 : 1;
      state.value = state.value.copyWith(
        commandHistoryIndex: (state.value.commandHistoryIndex + delta)
            .clampToLength(state.value.commandHistory.length),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      return _executeCommand();
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      state.value = state.value.copyWith(cursorPosition: 0);
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      state.value = state.value.copyWith(cursorPosition: cmd.length);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && isCtrl) {
      state.value = state.value.copyWith(
        cursorPosition: _previousWordBoundary(cmd, cursorPos),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && isCtrl) {
      state.value = state.value.copyWith(
        cursorPosition: _nextWordBoundary(cmd, cursorPos),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      state.value = state.value.copyWith(
        cursorPosition: max(0, cursorPos - 1),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      state.value = state.value.copyWith(
        cursorPosition: min(cmd.length, cursorPos + 1),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.backspace && isCtrl) {
      final boundary = _previousWordBoundary(cmd, cursorPos);
      state.value = state.value.copyWith(
        cmd: cmd.substring(0, boundary) + cmd.substring(cursorPos),
        cursorPosition: boundary,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (cursorPos > 0) {
        state.value = state.value.copyWith(
          cmd: cmd.substring(0, cursorPos - 1) + cmd.substring(cursorPos),
          cursorPosition: cursorPos - 1,
        );
      }
    } else if (event.logicalKey == LogicalKeyboardKey.delete && isCtrl) {
      final boundary = _nextWordBoundary(cmd, cursorPos);
      state.value = state.value.copyWith(
        cmd: cmd.substring(0, cursorPos) + cmd.substring(boundary),
      );
    } else if (event.logicalKey == LogicalKeyboardKey.delete) {
      if (cursorPos < cmd.length) {
        state.value = state.value.copyWith(
          cmd: cmd.substring(0, cursorPos) + cmd.substring(cursorPos + 1),
        );
      }
    } else if (char != null) {
      state.value = state.value.copyWith(
        cmd: cmd.substring(0, cursorPos) + char + cmd.substring(cursorPos),
        cursorPosition: cursorPos + char.length,
      );
    }
    return KeyEventResult.handled;
  }
}

extension on int {
  int clampToLength(int length) {
    // NOTE: this required due to a bug with the Dart compiler
    // ignore: unnecessary_this
    return this.clamp(0, max(0, length - 1));
  }
}
