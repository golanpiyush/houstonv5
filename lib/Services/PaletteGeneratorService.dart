import 'dart:io';
import 'dart:async'; // Add this import for TimeoutException
import 'dart:typed_data'; // Add this for Uint8List
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteGeneratorService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Extracts the vibrant color from either a network image URL or local file path
  Future<Color> getVibrantColor(String imagePath) async {
    if (imagePath.isEmpty) {
      debugPrint('Empty image path provided');
      return Colors.grey;
    }

    try {
      final ImageProvider imageProvider = _getImageProvider(imagePath);
      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        imageProvider,
        timeout: _timeout,
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Palette generation timed out');
      });

      // Try different color options in order of preference
      return paletteGenerator.vibrantColor?.color ??
          paletteGenerator.dominantColor?.color ??
          paletteGenerator.lightVibrantColor?.color ??
          paletteGenerator.darkVibrantColor?.color ??
          Colors.grey;
    } on TimeoutException catch (e) {
      debugPrint('Timeout generating palette: $e');
      return Colors.grey;
    } catch (e) {
      debugPrint('Error generating palette: $e');
      return Colors.grey;
    }
  }

  /// Determines the appropriate ImageProvider based on the image path
  ImageProvider _getImageProvider(String imagePath) {
    try {
      final uri = Uri.tryParse(imagePath);

      if (uri?.hasScheme ?? false) {
        // Handle network images
        return NetworkImage(imagePath);
      } else {
        // Handle local file images
        final file = File(imagePath);
        if (!file.existsSync()) {
          throw Exception('Local file does not exist: $imagePath');
        }
        return FileImage(file);
      }
    } catch (e) {
      debugPrint('Error creating image provider: $e');
      // Return a simple colored image provider as fallback
      return MemoryImage(Uint8List.fromList(List.filled(1, 128)));
    }
  }

  /// Validates if a string is a valid URL
  bool _isValidUrl(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
