import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/address_scan_service.dart';

class AddressFieldWithScan extends StatefulWidget {
  const AddressFieldWithScan({
    super.key,
    required this.controller,
    this.labelText = 'Indirizzo visita',
    this.hintText =
        'Es. Via Roma 143, 80100 Napoli NA (ancora meglio con CAP)',
    this.maxLines = 2,
    this.enabled = true,
    this.onScanned,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final int maxLines;
  final bool enabled;
  final VoidCallback? onScanned;

  @override
  State<AddressFieldWithScan> createState() => _AddressFieldWithScanState();
}

class _AddressFieldWithScanState extends State<AddressFieldWithScan> {
  bool _scanning = false;

  Future<void> _scan() async {
    if (!widget.enabled || _scanning) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli da galleria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _scanning = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analisi foto in corso…'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final address =
          await AddressScanService.captureAndExtractAddress(source: source);
      if (!mounted) return;

      if (address == null || address.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessun indirizzo rilevato. Riprova con una foto più nitida.',
            ),
          ),
        );
        return;
      }

      widget.controller.text = address.trim();
      widget.onScanned?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indirizzo inserito dalla scansione.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scansione non riuscita: $e')),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled && !_scanning,
      maxLines: widget.maxLines,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Scansiona indirizzo con fotocamera',
          onPressed: widget.enabled && !_scanning ? _scan : null,
          icon: _scanning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera_outlined),
        ),
      ),
    );
  }
}
