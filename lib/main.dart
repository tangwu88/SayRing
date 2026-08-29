import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'services/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController.production();
  runApp(SaydianApp(controller: controller));
  unawaited(controller.initialize());
}
