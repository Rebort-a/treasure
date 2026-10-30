import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/00.common/l10n/strings.dart';
import 'package:treasure/00.common/model/notifiers.dart';
import 'package:treasure/00.common/network/protocol/network_message.dart';
import 'package:treasure/00.common/widget/component/chat_component.dart';

class _FilePicker extends FilePickerPlatform {
  Completer<Uri?>? result;
  bool fail = false;
  int saves = 0;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    saves++;
    if (fail) throw PlatformException(code: 'save_failed');
    return result == null ? null : await result!.future;
  }
}

void main() {
  late FilePickerPlatform original;
  late _FilePicker picker;
  late ListNotifier<NetworkMessage> messages;

  setUp(() {
    original = FilePickerPlatform.instance;
    picker = _FilePicker();
    FilePickerPlatform.instance = picker;
    messages = ListNotifier([]);
  });

  tearDown(() {
    FilePickerPlatform.instance = original;
    messages.dispose();
  });

  Future<void> showAttachment(WidgetTester tester, String data) async {
    messages.add(
      NetworkMessage(
        id: 2,
        type: MessageType.file,
        source: 'Peer',
        content: jsonEncode({
          'name': 'attachment.txt',
          'data': data,
          'size': 1,
        }),
        timestamp: 1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageList(
            identity: 1,
            userName: 'Local',
            messageList: messages,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('attachment.txt'));
    await tester.pumpAndSettle();
  }

  testWidgets('损坏附件与保存失败均可提示，失败后仍可再次操作', (tester) async {
    await showAttachment(tester, '%%%');
    expect(picker.saves, 0);
    expect(find.textContaining(S.saveFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    messages.clear();
    picker.fail = true;
    await showAttachment(tester, 'AQ==');
    expect(picker.saves, 1);
    expect(find.textContaining(S.saveFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('取消保存不提示错误，页面退出后迟到的保存结果不再访问界面', (tester) async {
    await showAttachment(tester, 'AQ==');
    expect(picker.saves, 1);
    expect(find.textContaining(S.saveFailed), findsNothing);
    picker.result = Completer<Uri?>();
    await tester.tap(find.text('attachment.txt'));
    await tester.pump();
    expect(picker.saves, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    picker.result!.complete(Uri.file('/saved/attachment.txt'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
