import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Inicializar Firebase aquí en el Sprint 1
  runApp(const TestingCodeApp());
}

class TestingCodeApp extends StatelessWidget {
  const TestingCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talleres Cabimas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'TestingCode: Setup Inicial Completo 🚀',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}