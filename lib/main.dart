import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'presentation/pages/shell_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  runApp(const ProviderScope(child: TuSolutionApp()));
}

class TuSolutionApp extends StatelessWidget {
  const TuSolutionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tu Solution',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const ShellPage(),
      );
}
