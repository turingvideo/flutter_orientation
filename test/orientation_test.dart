import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orientation/orientation.dart';

void main() {
  const channel = MethodChannel('sososdk.github.com/orientation');
  const events = MethodChannel('sososdk.github.com/orientationEvent');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  test('preferred orientations keep the existing native method contract',
      () async {
    await OrientationPlugin.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeRight,
    ]);
    expect(calls.single.method, 'SystemChrome.setPreferredOrientations');
    expect(calls.single.arguments, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  test('forced orientation keeps the existing native method contract',
      () async {
    await OrientationPlugin.forceOrientation(DeviceOrientation.landscapeLeft);
    expect(calls.single.method, 'SystemChrome.forceOrientation');
    expect(calls.single.arguments, 'DeviceOrientation.landscapeLeft');
  });

  test('Duo inner orientation policy can be configured and cleared on iOS',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await OrientationPlugin.setDuoInnerOrientation(
        DeviceOrientation.portraitUp);
    await OrientationPlugin.setDuoInnerOrientation(null);
    expect(calls.map((call) => call.method), [
      'SystemChrome.setDuoInnerOrientation',
      'SystemChrome.setDuoInnerOrientation',
    ]);
    expect(calls.first.arguments, 'DeviceOrientation.portraitUp');
    expect(calls.last.arguments, isNull);
  });

  test('Duo inner orientation policy does not call Android native code',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await OrientationPlugin.setDuoInnerOrientation(
        DeviceOrientation.portraitUp);
    await OrientationPlugin.setDuoInnerOrientation(null);
    expect(calls, isEmpty);
  });

  test('orientation events remain independent from Duo events', () async {
    final received = <DeviceOrientation>[];
    final subscription =
        OrientationPlugin.onOrientationChange.listen(received.add);
    await Future<void>.delayed(Duration.zero);
    for (final orientation in DeviceOrientation.values) {
      await messenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec()
            .encodeSuccessEnvelope(orientation.toString()),
        (_) {},
      );
    }
    expect(received, DeviceOrientation.values);
    await subscription.cancel();
    expect(const DuoLayout().edge, NavigationEdge.none);
  });
}
