import 'package:flutter/material.dart';

class SaydianBrandLockup extends StatelessWidget {
  const SaydianBrandLockup({super.key, this.width = 190});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Saydian',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            SaydianBrandMark(size: width * .28),
            SizedBox(width: width * .06),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Saydian',
                  style: TextStyle(
                    fontSize: width * .20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFCA0B27),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaydianBrandMark extends StatelessWidget {
  const SaydianBrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/saidian-brand-mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Saydian',
    );
  }
}
