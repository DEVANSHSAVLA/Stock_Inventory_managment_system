import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_urls.dart';
import '../storage/secure_storage.dart';
import '../network/dio_client.dart';

class LocalServerDiscovery {
  static final LocalServerDiscovery _instance = LocalServerDiscovery._internal();
  factory LocalServerDiscovery() => _instance;
  LocalServerDiscovery._internal();

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  /// Tries to find the running Django backend on the local network.
  /// If found, updates [ApiUrls] and [DioClient], and saves the URL to [SecureStorage].
  Future<String?> discoverAndConfigure() async {
    if (_isDiscovering) return null;
    _isDiscovering = true;
    debugPrint('[Discovery] Starting local server discovery...');

    try {
      // 1. Try saved server URL first if available
      final savedUrl = await SecureStorage().getServerUrl();
      if (savedUrl != null && savedUrl.isNotEmpty) {
        debugPrint('[Discovery] Testing saved server URL: $savedUrl');
        final ok = await verifyServer(savedUrl);
        if (ok) {
          debugPrint('[Discovery] Saved server URL is valid: $savedUrl');
          _applyServerUrl(savedUrl);
          _isDiscovering = false;
          return savedUrl;
        }
      }

      // 2. Try localhost / 10.0.2.2 (Android Emulator loopback)
      final localHosts = [
        'http://localhost:8000',
        'http://10.0.2.2:8000',
        'http://127.0.0.1:8000',
      ];
      for (final host in localHosts) {
        final ok = await verifyServer(host);
        if (ok) {
          debugPrint('[Discovery] Found server on local host: $host');
          await SecureStorage().saveServerUrl(host);
          _applyServerUrl(host);
          _isDiscovering = false;
          return host;
        }
      }

      // 3. Scan the local network subnet
      final localIp = await _getLocalIP();
      if (localIp == null) {
        debugPrint('[Discovery] No local IP found. Skipping subnet scan.');
        _isDiscovering = false;
        return null;
      }

      debugPrint('[Discovery] Local IP detected: $localIp. Scanning subnet...');
      final parts = localIp.split('.');
      if (parts.length == 4) {
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
        final foundUrl = await _scanSubnet(subnet);
        if (foundUrl != null) {
          debugPrint('[Discovery] Server found and verified at: $foundUrl');
          await SecureStorage().saveServerUrl(foundUrl);
          _applyServerUrl(foundUrl);
          _isDiscovering = false;
          return foundUrl;
        }
      }
    } catch (e) {
      debugPrint('[Discovery] Error during server discovery: $e');
    }

    _isDiscovering = false;
    debugPrint('[Discovery] Server discovery completed. No server found.');
    return null;
  }

  void _applyServerUrl(String url) {
    ApiUrls.setBaseUrl(url);
    DioClient().updateBaseUrl(url);
  }

  Future<bool> verifyServer(String url) async {
    try {
      final isLocal = url.contains('localhost') || url.contains('127.0.0.1') || url.contains('192.168.') || url.contains('10.0.2.2');
      final timeout = isLocal ? const Duration(milliseconds: 1500) : const Duration(seconds: 15);
      final dio = Dio(BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
      ));
      final response = await dio.get('$url/api/public/resolve-tenant/');
      // Django DRF will respond with 200 or 405 Method Not Allowed (since GET is not allowed on resolve-tenant)
      if (response.statusCode == 200 || response.statusCode == 405 || response.statusCode == 400) {
        return true;
      }
    } catch (e) {
      if (e is DioException) {
        // A response from the server (even error status codes like 405, 400, 401) means the server is reachable
        if (e.response != null) {
          return true;
        }
      }
    }
    return false;
  }

  Future<String?> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            // Avoid virtual network interfaces if possible
            if (interface.name.toLowerCase().contains('virtual') || 
                interface.name.toLowerCase().contains('wsl') ||
                interface.name.toLowerCase().contains('vbox')) {
              continue;
            }
            return addr.address;
          }
        }
      }
      // Fallback to any non-loopback address if specific interfaces are filtered
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _scanSubnet(String subnet) async {
    final completer = Completer<String?>();
    int pending = 254;

    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet$i';
      final host = 'http://$ip:8000';
      
      // Perform quick socket connect check before HTTP verification to prevent socket resource leaks
      Socket.connect(ip, 8000, timeout: const Duration(milliseconds: 400)).then((socket) {
        socket.destroy();
        // If socket connected successfully, verify if it is indeed our Django server
        verifyServer(host).then((isValid) {
          if (isValid && !completer.isCompleted) {
            completer.complete(host);
          }
          pending--;
          if (pending == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        });
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    // Set a hard timeout for the entire scan task
    return completer.future.timeout(const Duration(seconds: 4), onTimeout: () => null);
  }
}
