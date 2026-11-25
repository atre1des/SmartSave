import 'package:flutter/material.dart';

import 'platform_web/workspace_stub.dart'
    if (dart.library.js_interop) 'platform_web/workspace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runBrowserWorkspace(review: true);
}
