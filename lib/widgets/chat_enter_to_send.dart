/// Enter 发送、Shift+Enter 换行（聊天输入框通用快捷键）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 拦截 Enter 触发 [onSend]；Shift+Enter 交给 TextField 插入换行。
KeyEventResult handleChatEnterToSend(
  FocusNode node,
  KeyEvent event,
  VoidCallback onSend, {
  bool enabled = true,
}) {
  if (!enabled) return KeyEventResult.ignored;
  if (event is! KeyDownEvent) return KeyEventResult.ignored;
  final key = event.logicalKey;
  if (key != LogicalKeyboardKey.enter &&
      key != LogicalKeyboardKey.numpadEnter) {
    return KeyEventResult.ignored;
  }
  if (HardwareKeyboard.instance.isShiftPressed) {
    return KeyEventResult.ignored;
  }
  onSend();
  return KeyEventResult.handled;
}
