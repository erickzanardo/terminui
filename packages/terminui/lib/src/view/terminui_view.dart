import 'package:flutter/material.dart';
import 'package:terminui/src/controller.dart';
import 'package:terminui/src/view/container_builder.dart';
import 'package:terminui/src/view/cursor_builder.dart';
import 'package:terminui/src/view/history_builder.dart';
import 'package:terminui/terminui.dart';

typedef KeyEventCallback = KeyEventResult? Function(KeyEvent event);

class KeyboardEventEmitter {
  final List<KeyEventCallback> _listeners = [];

  void addListener(KeyEventCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(KeyEventCallback listener) {
    _listeners.remove(listener);
  }

  KeyEventResult emit(KeyEvent event) {
    for (final listener in _listeners) {
      final result = listener(event);
      if (result != null) {
        return result;
      }
    }

    return KeyEventResult.ignored;
  }

  void dispose() {
    _listeners.clear();
  }
}

typedef HistoryBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
  Widget child,
);

typedef ContainerBuilder = Widget Function(
  BuildContext context,
  Widget child,
);

/// A Terminal like view that can be used to be interacted with commands.
///
/// It should be registered as an overlay in the game widget
/// of the game you want to interact with.
///
class TerminuiView<S> extends StatefulWidget {
  const TerminuiView({
    required this.onClose,
    required this.commands,
    required this.subject,
    required this.keyboardEventEmitter,
    this.repository,
    this.containerBuilder,
    this.cursorBuilder,
    this.cursorColor,
    this.historyBuilder,
    this.textStyle,
    @visibleForTesting this.controller,
    super.key,
  });

  final S subject;
  final List<TerminuiCommand<S>> commands;
  final KeyboardEventEmitter keyboardEventEmitter;
  final VoidCallback onClose;
  final TerminuiRepository? repository;
  final TerminuiController? controller;

  final ContainerBuilder? containerBuilder;
  final WidgetBuilder? cursorBuilder;
  final HistoryBuilder? historyBuilder;

  final Color? cursorColor;
  final TextStyle? textStyle;

  @override
  State<TerminuiView> createState() => _TerminuiViewState();
}

class _TerminuiViewState extends State<TerminuiView> {
  late final repository = widget.repository ?? MemoryTerminuiRepository();

  late final Map<String, TerminuiCommand> _commandsMap = {
    for (final command in widget.commands) command.name: command,
  };

  late final _controller = widget.controller ??
      TerminuiController(
        repository: repository,
        subject: widget.subject,
        scrollController: _scrollController,
        onClose: widget.onClose,
        commands: _commandsMap,
      );

  late final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    widget.keyboardEventEmitter.addListener(_controller.handleKeyEvent);

    _controller.init();
  }

  @override
  void dispose() {
    widget.keyboardEventEmitter.removeListener(_controller.handleKeyEvent);
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cursorColor = widget.cursorColor ?? Colors.white;

    final textStyle = widget.textStyle ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
            );

    final historyBuilder = widget.historyBuilder ?? defaultHistoryBuilder;
    final containerBuilder = widget.containerBuilder ?? defaultContainerBuilder;
    final cursorBuilder = widget.cursorBuilder ?? defaultCursorBuilder;

    return ValueListenableBuilder(
      valueListenable: _controller.state,
      builder: (context, state, _) {
        return SizedBox(
          height: 400,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 48,
                child: containerBuilder(
                  context,
                  historyBuilder(
                    context,
                    _scrollController,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in state.history)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(line, style: textStyle),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.showHistory)
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: containerBuilder(
                    context,
                    SizedBox(
                      height: 168,
                      child: Column(
                        verticalDirection: VerticalDirection.up,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (state.commandHistory.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('No history', style: textStyle),
                            ),
                          for (var i = state.commandHistoryIndex;
                              i >= 0 && i >= state.commandHistoryIndex - 5;
                              i--)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ColoredBox(
                                color: i == state.commandHistoryIndex
                                    ? cursorColor.withOpacity(.5)
                                    : Colors.transparent,
                                child: Text(
                                  state.commandHistory[i],
                                  style: textStyle?.copyWith(
                                    color: i == state.commandHistoryIndex
                                        ? cursorColor
                                        : textStyle.color,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: containerBuilder(
                  context,
                  Row(
                    children: [
                      Text(state.cmd, style: textStyle),
                      SizedBox(width: (textStyle?.fontSize ?? 12) / 4),
                      cursorBuilder(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
