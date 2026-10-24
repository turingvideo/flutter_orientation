# orientation

A Flutter plugin for device&#x27;s orientation

[![pub](https://img.shields.io/pub/v/orientation.svg?style=flat)](https://pub.dev/packages/orientation)

Patch for [issues:13238](https://github.com/flutter/flutter/issues/13238)

Patch for [issues:23913](https://github.com/flutter/flutter/issues/23913) point 4 

## iPhone Duo layout

The plugin also provides `DuoLayoutController`, `DuoLayout`, `NavigationEdge`, and `DuoHingeStatus`
through `package:orientation/duo_layout.dart` and the existing
`package:orientation/orientation.dart` entry point. Native registration is
automatic; host apps do not need another plugin registration in `AppDelegate`.

```dart
import 'package:orientation/duo_layout.dart';

final layoutController = DuoLayoutController();
layoutController.addListener(() {
  final layout = layoutController.value;
  // Choose a bottom bar for `none`, or a side bar for `left` / `right`.
  // These are physical edges, already resolved for right-to-left layouts.
  print(layout.edge);
  print(layout.hingeStatus); // unknown / closed / partiallyOpen / fullyOpen
  print(layout.isExpanded); // partiallyOpen or fullyOpen
});
await layoutController.start();

// Dispose when the owning widget is removed.
layoutController.dispose();
```

`topObstruction` and `bottomObstruction` are clearances in logical pixels for the
side navigation strip. They are not padding for the entire page. They include
the native safe area and active camera occlusion regions intersecting that strip.
The host app still owns navigation widgets, fullscreen behavior, and content
safe-area handling. `NavigationEdge.none` means horizontal navigation is preferred
in the current layout; it is not a device-model check.

### Opening and closing

The same controller notifies listeners when `hingeStatus` changes, even if the
navigation edge stays the same. This uses UIKit's `UIHingeInteraction`, not window
width, orientation, or the navigation edge. Repeated angle updates within the
same status do not generate duplicate layout notifications.

`isExpanded` is true for both partially and fully open states. `isFullyOpen`
is true only when the system reports `fullyOpen`. `unknown` means the view has
no available hinge state, including unsupported devices or a detached view;
both getters return false in that state. An initial snapshot may be `unknown`
until UIKit delivers its first hinge update.

These values describe the hinge, not the current scene's display. For example,
an outer-display camera accessory can exist while the device is open. Use the
window's actual layout constraints for responsive UI, not hinge status as a
replacement for available space. See Apple's
[UIHingeInteraction documentation](https://developer.apple.com/documentation/uikit/uihingeinteraction).

Controllers share the native event stream. Disposing one controller does not
stop another controller's updates. Android, iOS below 27.1, and hosts with an older
native plugin keep the default layout without changing the existing orientation
APIs.

Building the iOS plugin requires Xcode 27.1 or newer. The runtime Duo APIs are
guarded with iOS 27.1 availability checks; the deployment target is unchanged.
