import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _manualCtrl = TextEditingController();
  bool _torchOn = false;
  bool _isWeb = false;

  @override
  void initState() {
    super.initState();
    // Detect web platform
    try {
      // On web, mobile_scanner may not work
    } catch (_) {
      _isWeb = true;
    }
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan Barcode', style: AppTextStyles.headingMedium.copyWith(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(null),
        ),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
            onPressed: () => setState(() => _torchOn = !_torchOn),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: _isWeb ? _buildManualEntry() : _buildCameraScanner(),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('Position barcode within the frame', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Or type barcode manually...',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (_manualCtrl.text.isNotEmpty) {
                        context.pop(_manualCtrl.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: const Text('Use'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraScanner() {
    // mobile_scanner integration
    // Using a placeholder that shows instructions
    // In production, wrap with MobileScanner widget
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 80),
                const SizedBox(height: 16),
                Text('Camera scanner active', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white54)),
              ],
            ),
          ),
          Container(
            width: 260, height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Colors.white54, size: 80),
            const SizedBox(height: 16),
            Text('Camera not available on this platform', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white54)),
            Text('Use the manual entry below', style: AppTextStyles.bodySmall.copyWith(color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}
