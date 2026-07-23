import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:today_eat_app/widgets/image_viewer.dart';

void main() {
  testWidgets('全屏查看器可以左右滑动浏览记录中的多张图片', (tester) async {
    final directory = await Directory.systemTemp.createTemp(
      'image_viewer_test',
    );
    addTearDown(() => directory.delete(recursive: true));

    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final first = File('${directory.path}${Platform.pathSeparator}first.png')
      ..writeAsBytesSync(imageBytes);
    final second = File('${directory.path}${Platform.pathSeparator}second.png')
      ..writeAsBytesSync(imageBytes);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                openImageViewer(context, [first.path, second.path]),
            child: const Text('查看图片'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('查看图片'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });
}
