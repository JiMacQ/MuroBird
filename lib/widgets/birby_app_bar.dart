import 'package:flutter/material.dart';

AppBar birbyBar(
  String title, {
  List<Widget>? actions,
  bool showBack = false, // <--- NUEVO
}) {
  return AppBar(
    leading: showBack ? const BackButton() : null, // <--- NUEVO
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.podcasts_rounded, color: Colors.white),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
    actions: actions,
  );
}
