import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orientation_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sososdk.github.com/orientation');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('manual direction requests retain portrait and landscape support',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MyApp()));
    await tester.pump();
    for (final entry in {
      'Landscape Right': 'landscapeRight',
      'Portrait': 'portraitUp'
    }.entries) {
      calls.clear();
      await tester.tap(find.text(entry.key));
      await tester.pump();
      expect(calls.first.method, 'SystemChrome.setPreferredOrientations');
      expect(calls.first.arguments,
          supportedOrientations.map((value) => value.toString()).toList());
      expect(calls.last.method, 'SystemChrome.forceOrientation');
      expect(calls.last.arguments, 'DeviceOrientation.${entry.value}');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('example configures and clears the native entry preference',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const methods = MethodChannel('sososdk.github.com/orientation/duoLayout');
    const events =
        MethodChannel('sososdk.github.com/orientation/duoLayoutEvent');
    messenger.setMockMethodCallHandler(
        methods, (_) async => {'hingeStatus': 'closed'});
    messenger.setMockMethodCallHandler(events, (_) async => null);
    await tester.pumpWidget(const MaterialApp(home: MyApp()));
    await tester.pump();
    expect(calls.single.method, 'SystemChrome.setDuoInnerOrientation');
    expect(calls.single.arguments, 'DeviceOrientation.portraitUp');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(calls.last.arguments, isNull);
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}
