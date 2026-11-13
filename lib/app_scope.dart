import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// Gives the widget tree access to the [AppController]. Widgets that call
/// [of] rebuild whenever the controller notifies.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller; the calling widget rebuilds on every change.
  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }

  /// The controller without subscribing to its changes (for event handlers).
  static AppController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }
}
