import 'package:flutter/material.dart';

void main() => runApp(const NeuroTraceApp());

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroTrace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _BuildOKScreen(),
    );
  }
}

class _BuildOKScreen extends StatelessWidget {
  const _BuildOKScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'NeuroTrace build OK',
          style: TextStyle(
            color: Colors.greenAccent.shade200,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
