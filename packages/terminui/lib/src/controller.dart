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
  });

  final bool showHistory;
  final int commandHistoryIndex;
  final List<String> commandHistory;
  final List<String> history;
  final String cmd;

  TerminuiState copyWith({
    bool? showHistory,
    int? commandHistoryIndex,
    List<String>? commandHistory,
    List<String>? history,
    String? cmd,
  }) {
    return TerminuiState(
      showHistory: showHistory ?? this.showHistory,
      commandHistoryIndex: commandHistoryIndex ?? this.commandHistoryIndex,
      commandHistory: commandHistory ?? this.commandHistory,
      history: history ?? this.history,
      cmd: cmd ?? this.cmd,
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

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.handled;
    }
    final char = event.character;

    final showHistory = state.value.showHistory;
    final hasHistory = showHistory && state.value.commandHistory.isNotEmpty;

    if (event.logicalKey == LogicalKeyboardKey.escape && !showHistory) {
      onClose();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && !showHistory) {
      final newState = state.value.copyWith(
        showHistory: true,
        commandHistoryIndex: state.value.commandHistory.length - 1,
      );
      state.value = newState;
    } else if (event.logicalKey == LogicalKeyboardKey.enter && showHistory) {
      final newState = state.value.copyWith(
        cmd: hasHistory
            ? state.value.commandHistory[state.value.commandHistoryIndex]
            : state.value.cmd,
        showHistory: false,
      );
      state.value = newState;
    } else if ((event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) &&
        hasHistory) {
      final delta = event.logicalKey == LogicalKeyboardKey.arrowUp ? -1 : 1;
      final newState = state.value.copyWith(
        commandHistoryIndex: (state.value.commandHistoryIndex + delta)
            .clampToLength(state.value.commandHistory.length),
      );
      state.value = newState;
    } else if (event.logicalKey == LogicalKeyboardKey.escape && showHistory) {
      state.value = state.value.copyWith(
        showHistory: false,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      final split = state.value.cmd.split(' ').where((e) => e.isNotEmpty);

      if (split.isEmpty) {
        return KeyEventResult.handled;
      }

      if (split.first == 'clear') {
        state.value = state.value.copyWith(
          history: [],
          cmd: '',
        );
        return KeyEventResult.handled;
      }

      if (split.first == 'help') {
        final output = commands.entries.fold('', (previous, entry) {
          final help = '${entry.key} - ${entry.value.description}'
              '${entry.value.parser.usage}';

          state.value = state.value.copyWith(
            cmd: '',
          );

          return '$previous\n$help';
        });

        state.value = state.value.copyWith(
          history: [...state.value.history, output],
        );
        return KeyEventResult.handled;
      }

      final originalCommand = state.value.cmd;
      state.value = state.value.copyWith(
        history: [...state.value.history, state.value.cmd],
        cmd: '',
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final cmd = state.value.cmd;
      final endIndex = (cmd.length - 1).clampToLength(cmd.length);
      state.value = state.value.copyWith(
        cmd: cmd.substring(0, endIndex),
      );
    } else if (char != null) {
      state.value = state.value.copyWith(
        cmd: state.value.cmd + char,
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
