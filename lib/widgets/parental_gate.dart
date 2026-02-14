import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a parental gate dialog with a simple math problem
/// Returns true if the challenge was passed
Future<bool> showParentalGate(BuildContext context) async {
  final random = Random();
  final a = random.nextInt(10) + 1; // 1-10
  final b = random.nextInt(10) + 1; // 1-10
  final answer = a + b;

  final controller = TextEditingController();
  final focusNode = FocusNode();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text('Parental Gate', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Please ask your parents to solve this:',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Text(
            '$a + $b = ?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              hintText: 'Enter answer',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (value) {
              if (int.tryParse(value) == answer) {
                Navigator.pop(context, true);
              } else {
                Navigator.pop(context, false);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (int.tryParse(controller.text) == answer) {
              Navigator.pop(context, true);
            } else {
              Navigator.pop(context, false);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    ),
  );

  return result ?? false;
}
