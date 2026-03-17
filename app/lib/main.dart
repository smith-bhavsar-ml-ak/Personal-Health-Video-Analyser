import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/api/client.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean URLs on web (no # fragment routing)
  usePathUrlStrategy();

  // Initialise Dio with stored server URL / web base
  await ApiClient.instance.init();

  runApp(const ProviderScope(child: PhvaApp()));
}
