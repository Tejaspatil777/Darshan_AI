import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load persisted JWT tokens before the first frame so a saved session can
  // be restored on the splash screen.
  final TokenStore tokenStore = TokenStore();
  await tokenStore.load();
  runApp(MeritendanceApp(tokenStore: tokenStore));
}

