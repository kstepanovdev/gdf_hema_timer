import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/gen/app_localizations.dart';
import '../modules/opossum/pairing.dart';

bool get supportsPairingCamera =>
    !kIsWeb &&
    [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ].contains(defaultTargetPlatform);

class OpossumScanPage extends StatefulWidget {
  const OpossumScanPage({super.key, this.allowLocalHttp = false});
  final bool allowLocalHttp;
  @override
  State<OpossumScanPage> createState() => _OpossumScanPageState();
}

class _OpossumScanPageState extends State<OpossumScanPage> {
  final _camera = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _returned = false, _invalid = false;
  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.scanPairingQr)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _camera,
              onDetect: (capture) {
                if (_returned) return;
                final value = capture.barcodes
                    .map((b) => b.rawValue)
                    .whereType<String>()
                    .firstOrNull;
                if (value == null) return;
                try {
                  PairingLink.parse(
                    value,
                    allowLocalHttp: widget.allowLocalHttp,
                  );
                } on FormatException {
                  setState(() => _invalid = true);
                  return;
                }
                _returned = true;
                Navigator.of(context).pop(value);
              },
              onDetectError: (_, _) {
                if (mounted) setState(() => _invalid = true);
              },
              errorBuilder: (_, _) => Center(child: Text(l.cameraUnavailable)),
            ),
          ),
          if (_invalid) Text(l.invalidPairingQr),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.manualConnection),
          ),
        ],
      ),
    );
  }
}
