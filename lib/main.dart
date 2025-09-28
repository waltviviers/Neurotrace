import 'package:flutter/material.dart';

class _Tile extends StatelessWidget {
  final bool lit;

  // Define the colors so the compiler is happy
  final Color _highlightColor = Colors.yellow;
  final Color _baseColor = Colors.blue;

  const _Tile({Key? key, this.lit = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: lit ? _highlightColor.withOpacity(0.9) : _baseColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (lit)
            BoxShadow(
              color: _highlightColor.withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
    );
  }
}
