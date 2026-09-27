import 'package:flutter/material.dart';

import 'features/reminders/services/notification_service.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const AppSmarana());
}
