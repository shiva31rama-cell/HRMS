import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const int _maxPhotoBytes = 8 * 1024 * 1024;

class MaintenancePhoto {
  const MaintenancePhoto({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });

  final Uint8List bytes;
  final String mimeType;
  final String name;
}

Future<MaintenancePhoto?> showMaintenancePhotoCapture(BuildContext context) {
  return showDialog<MaintenancePhoto>(
    context: context,
    builder: (_) => const _MaintenancePhotoCaptureDialog(),
  );
}

class _MaintenancePhotoCaptureDialog extends StatefulWidget {
  const _MaintenancePhotoCaptureDialog();

  @override
  State<_MaintenancePhotoCaptureDialog> createState() => _MaintenancePhotoCaptureDialogState();
}

class _MaintenancePhotoCaptureDialogState extends State<_MaintenancePhotoCaptureDialog> {
  CameraController? _controller;
  bool _startingCamera = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  Future<void> _startCamera() async {
    CameraController? candidate;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera was found. Choose a photo from your device instead.');
      }
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      candidate = CameraController(selected, ResolutionPreset.medium, enableAudio: false);
      await candidate.initialize();
      if (!mounted) {
        await candidate.dispose();
        return;
      }
      setState(() => _controller = candidate);
    } catch (_) {
      if (candidate != null) {
        try {
          await candidate.dispose();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _error = 'Camera is unavailable or permission was denied. You can choose an existing photo instead.');
      }
    } finally {
      if (mounted) setState(() => _startingCamera = false);
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      _finish(bytes, 'image/jpeg', 'maintenance-photo.jpg');
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not capture the photo. Try again or choose a file.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choosePhoto() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final name = file.name;
      final lower = name.toLowerCase();
      final declaredMime = file.mimeType?.toLowerCase();
      final mimeType = declaredMime == 'image/png' || lower.endsWith('.png')
          ? 'image/png'
          : declaredMime == 'image/webp' || lower.endsWith('.webp')
              ? 'image/webp'
              : declaredMime == 'image/jpeg' || lower.endsWith('.jpg') || lower.endsWith('.jpeg')
                  ? 'image/jpeg'
                  : null;
      if (mimeType == null) {
        setState(() => _error = 'Choose a JPG, PNG, or WebP photo.');
        return;
      }
      _finish(await file.readAsBytes(), mimeType, name);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open that photo. Please try another one.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _finish(Uint8List bytes, String mimeType, String name) {
    if (bytes.length > _maxPhotoBytes) {
      if (mounted) setState(() => _error = 'This photo is larger than 8 MB. Choose a smaller image.');
      return;
    }
    Navigator.of(context).pop(MaintenancePhoto(
      bytes: bytes,
      mimeType: mimeType,
      name: name.isEmpty ? 'maintenance-photo' : name,
    ));
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return AlertDialog(
      title: const Text('Add a maintenance photo'),
      content: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (controller != null && controller.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
            )
          else
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _startingCamera
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.photo_camera_outlined, size: 44, color: Color(0xFF68766F)),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!, style: const TextStyle(color: Color(0xFF9A3030), height: 1.35)),
            ),
          ],
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Attach one clear photo of the repair issue. Avoid including people or personal information.',
              style: TextStyle(fontSize: 12, color: Color(0xFF68766F), height: 1.35),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton.icon(
          onPressed: _busy ? null : _choosePhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose photo'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: ready && !_busy ? _capture : null,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt_outlined),
          label: Text(_busy ? 'Working…' : 'Take photo'),
        ),
      ],
    );
  }
}
