import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orientation/duo_layout.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final eventMethods = MethodChannel(DuoLayoutController.eventChannel.name);
  late List<String> eventCalls;

  setUp(() {
    eventCalls = [];
    messenger.setMockMethodCallHandler(eventMethods, (call) async {
      eventCalls.add(call.method);
      return null;
    });
  });
  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(DuoLayoutController.methodChannel, null);
    messenger.setMockMethodCallHandler(eventMethods, null);
  });

  Future<void> sendEvent(Object? data, {bool error = false}) async {
    await messenger.handlePlatformMessage(
      DuoLayoutController.eventChannel.name,
      error
          ? const StandardMethodCodec().encodeErrorEnvelope(code: 'unavailable')
          : const StandardMethodCodec().encodeSuccessEnvelope(data),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
  }

  test('parses physical edges and rejects invalid obstruction values', () {
    expect(DuoLayout.fromPlatform(null), const DuoLayout());
    expect(DuoLayout.fromPlatform({'edge': 'unknown'}), const DuoLayout());
    expect(
      DuoLayout.fromPlatform({
        'edge': 'right',
        'topObstruction': 80,
        'bottomObstruction': 12.5,
      }),
      const DuoLayout(
        edge: NavigationEdge.right,
        topObstruction: 80,
        bottomObstruction: 12.5,
      ),
    );
    expect(
      DuoLayout.fromPlatform({
        'edge': 'left',
        'topObstruction': -1,
        'bottomObstruction': double.infinity,
      }),
      const DuoLayout(edge: NavigationEdge.left),
    );
  });

  test(
    'initial query and live events update layout without duplicate listeners',
    () async {
      var queries = 0;
      messenger.setMockMethodCallHandler(DuoLayoutController.methodChannel, (
        call,
      ) async {
        expect(call.method, 'getLayout');
        queries++;
        return {'edge': 'right'};
      });
      final controller = DuoLayoutController(platform: TargetPlatform.iOS);
      var changes = 0;
      controller.addListener(() => changes++);
      await controller.start();
      await controller.start();
      await Future<void>.delayed(Duration.zero);
      expect(queries, 1);
      expect(eventCalls, ['listen']);
      expect(controller.value.edge, NavigationEdge.right);
      await sendEvent({'edge': 'right'});
      expect(changes, 1);
      await sendEvent({'edge': 'left', 'topObstruction': 60});
      expect(
        controller.value,
        const DuoLayout(edge: NavigationEdge.left, topObstruction: 60),
      );
      await sendEvent({'edge': 'none'});
      expect(controller.value, const DuoLayout());
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(eventCalls, ['listen', 'cancel']);
    },
  );

  test('parses hinge states independently of the navigation edge', () {
    for (final status in DuoHingeStatus.values) {
      final layout = DuoLayout.fromPlatform({'hingeStatus': status.name});
      expect(layout.hingeStatus, status);
      expect(layout.edge, NavigationEdge.none);
      expect(
        layout.isExpanded,
        status == DuoHingeStatus.partiallyOpen ||
            status == DuoHingeStatus.fullyOpen,
      );
      expect(layout.isFullyOpen, status == DuoHingeStatus.fullyOpen);
      expect(layout, DuoLayout(hingeStatus: status));
      expect(layout.hashCode, DuoLayout(hingeStatus: status).hashCode);
    }
    expect(
      DuoLayout.fromPlatform({'edge': 'right'}).hingeStatus,
      DuoHingeStatus.unknown,
    );
    for (final invalid in [null, 'invalid', 3, false]) {
      expect(
        DuoLayout.fromPlatform({'hingeStatus': invalid}),
        const DuoLayout(),
      );
    }
    expect(
      const DuoLayout(hingeStatus: DuoHingeStatus.closed),
      isNot(const DuoLayout(hingeStatus: DuoHingeStatus.fullyOpen)),
    );
  });

  test('initial query can report an already unfolded device', () async {
    messenger.setMockMethodCallHandler(
      DuoLayoutController.methodChannel,
      (_) async => {'edge': 'none', 'hingeStatus': 'fullyOpen'},
    );
    final controller = DuoLayoutController(platform: TargetPlatform.iOS);
    await controller.start();
    expect(controller.value.hingeStatus, DuoHingeStatus.fullyOpen);
    expect(controller.value.isExpanded, isTrue);
    controller.dispose();
  });

  test('hinge-only changes notify listeners without moving navigation',
      () async {
    messenger.setMockMethodCallHandler(
      DuoLayoutController.methodChannel,
      (_) async => {'edge': 'right', 'hingeStatus': 'closed'},
    );
    final controller = DuoLayoutController(platform: TargetPlatform.iOS);
    final states = <DuoHingeStatus>[];
    controller.addListener(() => states.add(controller.value.hingeStatus));
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    await sendEvent({'edge': 'right', 'hingeStatus': 'closed'});
    await sendEvent({'edge': 'right', 'hingeStatus': 'partiallyOpen'});
    await sendEvent({'edge': 'right', 'hingeStatus': 'partiallyOpen'});
    await sendEvent({'edge': 'right', 'hingeStatus': 'fullyOpen'});
    expect(controller.value.edge, NavigationEdge.right);
    expect(controller.value.isFullyOpen, isTrue);
    await sendEvent({'edge': 'right', 'hingeStatus': 'closed'});
    expect(controller.value.isExpanded, isFalse);
    expect(states, [
      DuoHingeStatus.closed,
      DuoHingeStatus.partiallyOpen,
      DuoHingeStatus.fullyOpen,
      DuoHingeStatus.closed,
    ]);
    await sendEvent(null, error: true);
    expect(controller.value.hingeStatus, DuoHingeStatus.unknown);
    expect(controller.value.isExpanded, isFalse);
    controller.dispose();
  });

  test('controllers share one native listener until all are disposed',
      () async {
    var queries = 0;
    messenger.setMockMethodCallHandler(
      DuoLayoutController.methodChannel,
      (_) async {
        queries++;
        return {'edge': 'right'};
      },
    );
    final first = DuoLayoutController(platform: TargetPlatform.iOS);
    final second = DuoLayoutController(platform: TargetPlatform.iOS);
    await first.start();
    await second.start();
    await Future<void>.delayed(Duration.zero);
    expect(queries, 2);
    expect(eventCalls, ['listen']);
    await sendEvent({'edge': 'left'});
    expect(first.value.edge, NavigationEdge.left);
    expect(second.value.edge, NavigationEdge.left);
    first.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(eventCalls, ['listen']);
    await sendEvent({'edge': 'none'});
    expect(second.value, const DuoLayout());
    second.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(eventCalls, ['listen', 'cancel']);
  });

  test('a shared event takes priority over a pending initial query', () async {
    var queries = 0;
    final response = Completer<Object?>();
    messenger.setMockMethodCallHandler(
      DuoLayoutController.methodChannel,
      (_) async {
        queries++;
        if (queries == 1) return {'edge': 'right'};
        return response.future;
      },
    );
    final first = DuoLayoutController(platform: TargetPlatform.iOS);
    final second = DuoLayoutController(platform: TargetPlatform.iOS);
    await first.start();
    await Future<void>.delayed(Duration.zero);
    final started = second.start();
    await Future<void>.delayed(Duration.zero);
    await sendEvent({'edge': 'left', 'topObstruction': 60});
    response.complete({'edge': 'right'});
    await started;
    expect(second.value, first.value);
    expect(second.value.edge, NavigationEdge.left);
    first.dispose();
    second.dispose();
  });

  test('non-iOS platforms do not call native channels', () async {
    var queried = false;
    messenger.setMockMethodCallHandler(DuoLayoutController.methodChannel, (
      _,
    ) async {
      queried = true;
      return {'edge': 'right'};
    });
    final controller = DuoLayoutController(platform: TargetPlatform.android);
    await controller.start();
    expect(controller.value, const DuoLayout());
    expect(queried, isFalse);
    expect(eventCalls, isEmpty);
    controller.dispose();
  });

  for (final missing in [true, false]) {
    test(
      'unavailable native support falls back to bottom navigation (missing=$missing)',
      () async {
        messenger.setMockMethodCallHandler(DuoLayoutController.methodChannel, (
          _,
        ) async {
          if (missing) throw MissingPluginException();
          throw PlatformException(code: 'unavailable');
        });
        final controller = DuoLayoutController(platform: TargetPlatform.iOS);
        await controller.start();
        expect(controller.value, const DuoLayout());
        expect(eventCalls, isEmpty);
        controller.dispose();
      },
    );
  }

  test('stream errors restore the default layout', () async {
    messenger.setMockMethodCallHandler(
      DuoLayoutController.methodChannel,
      (_) async => {'edge': 'right'},
    );
    final controller = DuoLayoutController(platform: TargetPlatform.iOS);
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    await sendEvent(null, error: true);
    expect(controller.value, const DuoLayout());
    controller.dispose();
  });

  test('disposal after the initial notification cancels the native listener',
      () async {
    messenger.setMockMethodCallHandler(
      DuoLayoutController.methodChannel,
      (_) async => {'edge': 'right'},
    );
    final controller = DuoLayoutController(platform: TargetPlatform.iOS);
    controller.addListener(() => scheduleMicrotask(controller.dispose));
    await controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(eventCalls, ['listen', 'cancel']);
  });

  test('disposal during the initial query ignores its late response', () async {
    final response = Completer<Object?>();
    messenger.setMockMethodCallHandler(
      DuoLayoutController.methodChannel,
      (_) => response.future,
    );
    final controller = DuoLayoutController(platform: TargetPlatform.iOS);
    final started = controller.start();
    controller.dispose();
    response.complete({'edge': 'right'});
    await started;
    expect(eventCalls, isEmpty);
  });
}
