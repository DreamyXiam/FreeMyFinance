import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class AccountIcon extends StatefulWidget {
  final String name;
  final String pngBase64;
  final double size;
  const AccountIcon({
    super.key,
    required this.name,
    required this.pngBase64,
    this.size = 48,
  });
  @override
  State<AccountIcon> createState() => _AccountIconState();
}

class _AccountIconState extends State<AccountIcon> {
  Uint8List? bytes;
  @override
  void initState() {
    super.initState();
    decode();
  }

  @override
  void didUpdateWidget(covariant AccountIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pngBase64 != widget.pngBase64) decode();
  }

  void decode() {
    try {
      bytes = widget.pngBase64.isEmpty ? null : base64Decode(widget.pngBase64);
    } catch (_) {
      bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.name.trim();
    final initial = value.isEmpty
        ? '?'
        : String.fromCharCode(value.runes.first);
    final palette = const [
      Color(0xFF168F73),
      Color(0xFF1D78B5),
      Color(0xFF9A65B8),
      Color(0xFFBD7A22),
      Color(0xFF4F7F49),
    ];
    final color =
        palette[value.runes.fold(0, (int sum, code) => sum + code) %
            palette.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * .26),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: bytes == null
            ? DecoratedBox(
                decoration: BoxDecoration(color: color),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.size * .47,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
            : Image.memory(
                bytes!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => DecoratedBox(
                  decoration: BoxDecoration(color: color),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.size * .47,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
