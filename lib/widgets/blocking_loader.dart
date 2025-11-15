import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Muestra un diálogo bloqueante con spinner.
/// Cierra con: Navigator.pop(context)
void showBlockingLoader(
  BuildContext context, {
  String message = 'Procesando audio…',
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => WillPopScope(
      onWillPop: () async => false, // bloquea botón atrás
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(kBrand),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
