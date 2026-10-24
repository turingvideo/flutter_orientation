import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The system-preferred physical edge for vertical navigation.
enum NavigationEdge { none, left, right }

/// The system-reported hinge state, independent of navigation placement.
enum DuoHingeStatus { unknown, closed, partiallyOpen, fullyOpen }

/// Native navigation layout and hinge state for the current view hierarchy.
@immutable
class DuoLayout {
  final NavigationEdge edge;
  final double topObstruction;
  final double bottomObstruction;
  final DuoHingeStatus hingeStatus;

  const DuoLayout({
    this.edge = NavigationEdge.none,
    this.topObstruction = 0,
    this.bottomObstruction = 0,
    this.hingeStatus = DuoHingeStatus.unknown,
  });

  /// Whether the device is partially or fully unfolded.
  ///
  /// False for [DuoHingeStatus.unknown], including unsupported devices. This is
  /// not a window-size or current-display check; use layout constraints for UI.
  bool get isExpanded =>
      hingeStatus == DuoHingeStatus.partiallyOpen ||
      hingeStatus == DuoHingeStatus.fullyOpen;

  bool get isFullyOpen => hingeStatus == DuoHingeStatus.fullyOpen;

  factory DuoLayout.fromPlatform(Object? data) {
    if (data is! Map) return const DuoLayout();
    double inset(Object? value) =>
        value is num && value.isFinite && value >= 0 ? value.toDouble() : 0;
    return DuoLayout(
      edge: switch (data['edge']) {
        'left' => NavigationEdge.left,
        'right' => NavigationEdge.right,
        _ => NavigationEdge.none,
      },
      topObstruction: inset(data['topObstruction']),
      bottomObstruction: inset(data['bottomObstruction']),
      hingeStatus: switch (data['hingeStatus']) {
        'closed' => DuoHingeStatus.closed,
        'partiallyOpen' => DuoHingeStatus.partiallyOpen,
        'fullyOpen' => DuoHingeStatus.fullyOpen,
        _ => DuoHingeStatus.unknown,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DuoLayout &&
      edge == other.edge &&
      topObstruction == other.topObstruction &&
      bottomObstruction == other.bottomObstruction &&
      hingeStatus == other.hingeStatus;

  @override
  int get hashCode =>
      Object.hash(edge, topObstruction, bottomObstruction, hingeStatus);
}

/// Observes iOS Duo layout and hinge changes without choosing an app's UI.
///
/// Unsupported platforms and older native builds report [DuoLayout]'s defaults.
/// Call [start] once and [dispose] when the owning widget is removed.
class DuoLayoutController extends ValueNotifier<DuoLayout> {
  static const methodChannel =
      MethodChannel('sososdk.github.com/orientation/duoLayout');
  static const eventChannel =
      EventChannel('sososdk.github.com/orientation/duoLayoutEvent');
  static final Stream<dynamic> _layoutEvents =
      eventChannel.receiveBroadcastStream();
  static int _eventRevision = 0;
  static DuoLayout _latestEvent = const DuoLayout();

  final TargetPlatform _platform;
  StreamSubscription<dynamic>? _subscription;
  bool _started = false;
  bool _disposed = false;

  DuoLayoutController({TargetPlatform? platform})
      : _platform = platform ?? defaultTargetPlatform,
        super(const DuoLayout());

  Future<void> start() async {
    if (_started || _disposed || kIsWeb || _platform != TargetPlatform.iOS) {
      return;
    }
    _started = true;
    try {
      final revision = _eventRevision;
      final data = await methodChannel.invokeMethod<Object?>('getLayout');
      if (_disposed) return;
      // An existing controller may receive a newer event during this query.
      value = revision == _eventRevision
          ? DuoLayout.fromPlatform(data)
          : _latestEvent;
      if (_disposed) return;
      _subscription = _layoutEvents.listen(
        (data) {
          if (_disposed) return;
          _latestEvent = DuoLayout.fromPlatform(data);
          _eventRevision++;
          value = _latestEvent;
        },
        onError: (Object error) {
          if (_disposed) return;
          _latestEvent = const DuoLayout();
          _eventRevision++;
          value = _latestEvent;
        },
      );
    } on MissingPluginException {
      // A host with an older native plugin can keep its existing layout.
    } on PlatformException {
      if (!_disposed) value = const DuoLayout();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
