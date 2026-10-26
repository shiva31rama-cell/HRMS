import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MaintenancePhotoViewer extends StatefulWidget {
  const MaintenancePhotoViewer({
    super.key,
    required this.api,
    required this.requestId,
    required this.imageName,
  });

  final ApiService api;
  final String requestId;
  final String imageName;

  @override
  State<MaintenancePhotoViewer> createState() => _MaintenancePhotoViewerState();
}

class _MaintenancePhotoViewerState extends State<MaintenancePhotoViewer> {
  late Future<Uint8List> _photo;

  @override
  void initState() {
    super.initState();
    _photo = _load();
  }

  Future<Uint8List> _load() =>
      widget.api.getBytes('/maintenance/' + widget.requestId + '/image');

  void _openPhoto(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: InteractiveViewer(
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _photo,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Photo attachment could not be loaded.',
              style: TextStyle(color: Color(0xFF68766F), fontSize: 12),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            );
          }
          final bytes = snapshot.data!;
          return Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: widget.imageName,
              child: InkWell(
                onTap: () => _openPhoto(bytes),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260, maxHeight: 190),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 260,
                        height: 120,
                        child: Center(child: Text('Photo preview unavailable')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
