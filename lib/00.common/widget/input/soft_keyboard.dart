import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextField child;

  const CustomTextField({super.key, required this.child});

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

// CustomTextField的State类
class _CustomTextFieldState extends State<CustomTextField> {
  late TextEditingController _controller; // 文本控制器
  final FocusNode _focusNode = FocusNode(); // 焦点节点
  OverlayEntry? _overlayEntry; // 覆盖层入口

  @override
  void initState() {
    super.initState();
    // 初始化文本控制器
    _controller = widget.child.controller ?? TextEditingController();
    _controller.text = widget.child.controller?.text ?? '';
    // 添加焦点变化的监听器
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    // 移除焦点节点和覆盖层入口
    _focusNode.removeListener(_onFocusChange); // 移除焦点变化的监听器
    _focusNode.dispose();
    _hideCustomKeyboard();
    super.dispose();
  }

  // 焦点变化时的回调函数
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showCustomKeyboard(); // 显示自定义键盘
    } else {
      // _hideCustomKeyboard(); // 可以选择在这里移除覆盖层
    }
  }

  // 显示键盘
  void _showCustomKeyboard() {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) {
          return Positioned(
            // 定位自定义键盘
            bottom: 0,
            left: 0,
            right: 0,
            // 添加动画
            child: AnimatedContainer(
              curve: const Cubic(0.160, 0.265, 0.125, 0.995),
              duration: const Duration(milliseconds: 360),
              child: CustomKeyboard(
                onInputContent: _inputContent,
                onDeleteContent: _deleteContent,
                onHideKeyboard: _onHideKeyboard,
                onCursorMove: _moveCursor,
              ),
            ),
          );
        },
      );
      // 将覆盖层插入到当前上下文中
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    }
  }

  // 移除键盘
  void _hideCustomKeyboard() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove(); // 移除覆盖层
      _overlayEntry = null; // 清空引用
    }
  }

  // 输入内容
  void _inputContent(String character) {
    _focusNode.requestFocus();
    setState(() {
      // 获取当前文本和光标位置
      final text = _controller.text;
      final selection = _controller.selection;

      // 在光标位置插入字符
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        character,
      );

      // 更新文本字段的内容，并移动光标
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: selection.start + character.length),
      );
    });
  }

  // 删除内容
  void _deleteContent() {
    _focusNode.requestFocus();
    setState(() {
      // 获取当前文本和光标位置
      final text = _controller.text;
      final selection = _controller.selection;

      // 如果文本不为空且光标不在起始位置，则进行删除操作
      if (text.isNotEmpty && selection.start > 0) {
        // 删除光标前的字符
        final newText =
            text.substring(0, selection.start - 1) +
            text.substring(selection.start);

        // 更新文本字段的内容，并移动光标
        _controller.text = newText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.start - 1),
        );
      }
    });
  }

  // 移动光标
  void _moveCursor(String direction) {
    _focusNode.requestFocus();
    final currentCursorPosition = _controller.selection.start;
    final textLength = _controller.text.length;

    // 根据方向移动光标
    switch (direction) {
      case 'left':
        if (currentCursorPosition > 0) {
          _controller.selection = TextSelection.collapsed(
            offset: currentCursorPosition - 1,
          );
        }
        break;
      case 'right':
        if (currentCursorPosition < textLength) {
          _controller.selection = TextSelection.collapsed(
            offset: currentCursorPosition + 1,
          );
        }
        break;
      case 'up':
        // 光标向上移动的逻辑
        break;
      case 'down':
        // 光标向下移动的逻辑
        break;
    }
  }

  // 隐藏键盘
  void _onHideKeyboard() {
    _focusNode.unfocus(); // 移除焦点
    // 隐藏自定义键盘
    _hideCustomKeyboard();
  }

  // 构建方法，返回一个TextField
  @override
  Widget build(BuildContext context) {
    return TextField(
      // 显示光标
      showCursor: true,
      // 绑定焦点
      focusNode: _focusNode,
      // 使用自定义的文本控制器
      controller: _controller,
      // 装饰，从传入的child获取
      decoration: widget.child.decoration,
      // 文本样式，从传入的child获取
      style: widget.child.style,
      // 点击事件，从传入的child获取
      onChanged: widget.child.onChanged,
    );
  }
}

// 自定义键盘组件，继承自StatefulWidget
class CustomKeyboard extends StatefulWidget {
  // 输入内容时的回调
  final Function(String) onInputContent;
  // 删除内容时的回调
  final VoidCallback onDeleteContent;
  // 隐藏键盘时的回调
  final VoidCallback onHideKeyboard;
  // 光标移动时的回调
  final Function(String) onCursorMove;

  // 构造函数，使用回调函数初始化
  const CustomKeyboard({
    super.key,
    required this.onInputContent,
    required this.onDeleteContent,
    required this.onHideKeyboard,
    required this.onCursorMove,
  });

  // 创建状态
  @override
  State<CustomKeyboard> createState() => _CustomKeyboardState();
}

// CustomKeyboard的状态类
class _CustomKeyboardState extends State<CustomKeyboard> {
  // 普通键盘布局
  final Map<String, List<String>> normalKeyGroups = {
    'OneLine': ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '='],
    'TwoLine': ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']'],
    'ThreeLine': ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`'],
    'FourLine': ['z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', '\\'],
  };

  // 大写键盘布局
  final Map<String, List<String>> shiftedKeyGroups = {
    'OneLine': ['!', '@', '#', '\$', '%', '^', '&', '*', '(', ')', '_', '+'],
    'TwoLine': ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}'],
    'ThreeLine': ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~'],
    'FourLine': ['Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', '|'],
  };

  // 是否按下Shift键
  bool shiftPressed = false;

  // 切换Shift键状态
  void toggleShift() {
    setState(() {
      shiftPressed = !shiftPressed;
    });
  }

  // 构建方法，返回自定义键盘的布局
  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸
    final Size screenSize = MediaQuery.of(context).size;
    // 计算边距
    final double padding = screenSize.width * 0.002;
    // 计算按钮大小
    final double buttonSize = screenSize.width * 0.07;

    // 存储键盘行的列表
    List<Widget> rows = [];

    // 添加键盘的常规行
    for (var keyGroup in normalKeyGroups.keys) {
      // 根据Shift键的状态获取键标签
      List<String> labels = shiftPressed
          ? shiftedKeyGroups[keyGroup]!
          : normalKeyGroups[keyGroup]!;

      // 将键标签转换为按钮
      List<Widget> keyboardRowWidgets = labels.map((label) {
        return Expanded(
          flex: 1,
          child: KeyboardButton(
            label: label,
            onPressed: () => widget.onInputContent(label),
            padding: padding,
            buttonSize: buttonSize,
          ),
        );
      }).toList();

      // 在第四行添加Shift键
      if (keyGroup == 'FourLine') {
        keyboardRowWidgets.add(
          Expanded(
            flex: 1,
            child: KeyboardButton(
              label: shiftPressed ? '⇩' : '⇧',
              onPressed: toggleShift,
              padding: padding,
              buttonSize: buttonSize,
            ),
          ),
        );
      }

      // 将整行添加到rows列表中
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keyboardRowWidgets,
        ),
      );
    }

    // 添加最后一行，包含特殊键和光标移动键
    rows.add(
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 左光标移动键
          Expanded(
            flex: 1,
            child: KeyboardButton(
              label: '←',
              onPressed: () => widget.onCursorMove('left'),
              padding: padding,
              buttonSize: buttonSize,
            ),
          ),
          // 上光标移动键
          Expanded(
            flex: 1,
            child: KeyboardButton(
              label: '↑',
              onPressed: () => widget.onCursorMove('up'),
              padding: padding,
              buttonSize: buttonSize,
            ),
          ),
          // 下光标移动键
          Expanded(
            flex: 1,
            child: KeyboardButton(
              label: '↓',
              onPressed: () => widget.onCursorMove('down'),
              padding: padding,
              buttonSize: buttonSize,
            ),
          ),
          // 右光标移动键
          Expanded(
            flex: 1,
            child: KeyboardButton(
              label: '→',
              onPressed: () => widget.onCursorMove('right'),
              padding: padding,
              buttonSize: buttonSize,
            ),
          ),
          // 空格键
          Expanded(
            flex: 4,
            child: KeyboardButton(
              label: '␣',
              onPressed: () => widget.onInputContent(' '),
              padding: padding,
              buttonSize: buttonSize, // 使用扩展的大小
            ),
          ),
          // 删除键
          Expanded(
            flex: 1,
            child: KeyboardButton(
              label: '⌫',
              onPressed: () => widget.onDeleteContent(),
              padding: padding,
              buttonSize: buttonSize,
            ),
          ),
          // 回车键
          Expanded(
            flex: 1,
            child: KeyboardButton(
              label: '⏎',
              onPressed: widget.onHideKeyboard,
              padding: padding,
              buttonSize: buttonSize,
            ),
          ),
        ],
      ),
    );

    return Container(
      color: const Color.fromARGB(255, 0, 200, 255), // 键盘背景颜色
      child: Column(
        children: rows, // 所有行的Widget列表
      ),
    );
  }
}

// 键盘按钮组件，继承自StatelessWidget
class KeyboardButton extends StatelessWidget {
  // 按钮标签
  final String label;
  // 按钮点击回调
  final VoidCallback onPressed;
  // 按钮内边距
  final double padding;
  // 按钮大小
  final double buttonSize;

  // 构造函数
  const KeyboardButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.padding,
    required this.buttonSize,
  });

  // 构建方法，返回按钮的Widget
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding), // 设置内边距
      child: MaterialButton(
        onPressed: onPressed, // 设置点击回调
        color: Colors.blue, // 按钮颜色
        child: SizedBox(
          width: buttonSize, // 按钮宽度
          height: buttonSize * 0.4, // 按钮高度
          child: Center(
            child: Text(
              label, // 按钮标签
              style: TextStyle(
                color: Colors.white,
                fontSize: buttonSize * 0.2,
              ), // 标签样式
            ),
          ),
        ),
      ),
    );
  }
}
