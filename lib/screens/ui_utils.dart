import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Shows a dialog to update the ApiService's base URL.
Future<void> showConfigDialog(
  BuildContext context,
  ApiService apiService,
) async {
  final TextEditingController controller = TextEditingController(
    text: apiService.baseUrl,
  );
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Configure Server'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            hintText: 'http://10.0.2.2:5888',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final String newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await apiService.updateBaseUrl(newUrl);
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}
