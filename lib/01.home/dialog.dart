import 'package:flutter/material.dart';

import '../00.common/model/app_item_type.dart';
import '../00.common/l10n/strings.dart';
import '../00.common/network/protocol/network_room.dart';
import '../00.common/network/client/network_engine.dart';

class RoomDialog {
  static void showCreateRoomDialog({
    required BuildContext context,
    required void Function(String roomName, String? password) onConfirm,
  }) {
    var roomName = '';
    var password = '';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.createRoom),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(labelText: S.enterRoomName),
                onChanged: (value) => roomName = value,
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: S.roomPassword,
                  helperText: S.passwordOptional,
                ),
                onChanged: (value) => password = value,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final name = roomName.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext);
              onConfirm(name, password.trim().isEmpty ? null : password);
            },
            child: Text(S.create),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(S.cancel),
          ),
        ],
      ),
    );
  }
}

/// 入房任务由主页弹窗持有，只有认证成功才交出同一条连接。
class JoinRoomDialog extends StatefulWidget {
  final RoomInfo? room;
  final String userName;
  final String? password;
  final bool startImmediately;
  final ValueChanged<NetworkEngine> onAttempt;

  const JoinRoomDialog({
    super.key,
    this.room,
    required this.userName,
    this.password,
    this.startImmediately = false,
    required this.onAttempt,
  });

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  late final _name = TextEditingController(text: widget.userName);
  late final _password = TextEditingController(text: widget.password);
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _encryptionKey = TextEditingController();
  final _busy = ValueNotifier(false);
  final _error = ValueNotifier<String?>(null);
  NetworkEngine? _engine;
  bool _transferred = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    if (widget.startImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _join();
      });
    }
  }

  Future<void> _join() async {
    if (_busy.value || _cancelled) return;
    final name = _name.text.trim();
    final port = int.tryParse(_port.text);
    if (name.isEmpty ||
        (widget.room == null &&
            (_host.text.trim().isEmpty ||
                _encryptionKey.text.trim().isEmpty ||
                port == null ||
                port <= 0 ||
                port > 65535))) {
      return;
    }
    _busy.value = true;
    _error.value = null;
    _engine?.dispose();
    final target =
        widget.room ??
        RoomInfo(
          name: _host.text.trim(),
          type: OnlineItemType.onlyChat.index,
          address: _host.text.trim(),
          port: port!,
          encryptionKey: _encryptionKey.text.trim(),
        );
    final engine = NetworkEngine.forRoom(
      userName: name,
      endpoint: target.withPassword(_password.text),
    );
    _engine = engine;
    widget.onAttempt(engine);
    try {
      await engine.join();
      if (!mounted || _cancelled || !identical(_engine, engine)) {
        engine.dispose();
        return;
      }
      _transferred = true;
      Navigator.of(context).pop(engine);
    } on RoomJoinException catch (error) {
      engine.dispose();
      if (!mounted || _cancelled) return;
      _error.value = switch (error.reason) {
        RoomFailure.invalidPassword => S.incorrectRoomPassword,
        RoomFailure.timeout => S.roomJoinTimedOut,
        RoomFailure.cancelled => S.cancel,
        _ => S.roomJoinFailed,
      };
      _busy.value = false;
    }
  }

  void _cancel() {
    if (_cancelled || _transferred) return;
    _cancelled = true;
    _engine?.dispose();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!_transferred) _engine?.dispose();
    _name.dispose();
    _password.dispose();
    _host.dispose();
    _port.dispose();
    _encryptionKey.dispose();
    _busy.dispose();
    _error.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop && !_transferred) {
        _cancelled = true;
        _engine?.dispose();
      }
    },
    child: ValueListenableBuilder<bool>(
      valueListenable: _busy,
      builder: (_, busy, __) => AlertDialog(
        title: Text(S.joinRoom),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                enabled: !busy,
                decoration: InputDecoration(labelText: S.enterUserName),
              ),
              if (widget.room == null) ...[
                TextField(
                  controller: _host,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'IP'),
                ),
                TextField(
                  controller: _port,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: S.port),
                ),
                TextField(
                  controller: _encryptionKey,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: S.roomEncryptionKey,
                    helperText: S.roomEncryptionKeyRequired,
                  ),
                ),
              ],
              TextField(
                controller: _password,
                enabled: !busy,
                obscureText: true,
                decoration: InputDecoration(labelText: S.roomPassword),
                onSubmitted: (_) => _join(),
              ),
              if (busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(S.connecting),
              ],
              ValueListenableBuilder<String?>(
                valueListenable: _error,
                builder: (_, error, __) => error == null
                    ? const SizedBox.shrink()
                    : Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: busy ? null : _join, child: Text(S.join)),
          TextButton(onPressed: _cancel, child: Text(S.cancel)),
        ],
      ),
    ),
  );
}
