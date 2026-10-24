import 'package:flutter/widgets.dart';

/// Includes popup routes: a mounted chat tab underneath another route is not
/// an opened chat surface. Keyboard/build changes do not produce route events.
final chatRouteObserver = RouteObserver<ModalRoute<dynamic>>();
