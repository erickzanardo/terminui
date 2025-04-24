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

    if (event.logicalKey == LogicalKeyboardKey.escape &&
        !state.value.showHistory) {
      onClose();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        !state.value.showHistory) {
      final newState = state.value.copyWith(
        showHistory: true,
        commandHistoryIndex: state.value.commandHistory.length - 1,
      );
      state.value = newState;
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        state.value.showHistory) {
      final newState = state.value.copyWith(
        cmd: state.value.commandHistory[state.value.commandHistoryIndex],
        showHistory: false,
      );
      state.value = newState;
    } else if ((event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) &&
        state.value.showHistory) {
      final newState = state.value.copyWith(
        commandHistoryIndex: event.logicalKey == LogicalKeyboardKey.arrowUp
            ? (state.value.commandHistoryIndex - 1)
                .clamp(0, state.value.commandHistory.length - 1)
            : (state.value.commandHistoryIndex + 1)
                .clamp(0, state.value.commandHistory.length - 1),
      );
      state.value = newState;
    } else if (event.logicalKey == LogicalKeyboardKey.escape &&
        state.value.showHistory) {
      state.value = state.value.copyWith(
        showHistory: false,
      );
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        !state.value.showHistory) {
      final split = state.value.cmd.split(' ');

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
      state.value = state.value.copyWith(
        cmd: state.value.cmd.substring(
          0,
          max(state.value.cmd.length - 1, 0),
        ),
      );
    } else if (char != null) {
      state.value = state.value.copyWith(
        cmd: state.value.cmd + char,
      );
    }
    return KeyEventResult.handled;
  }
}
