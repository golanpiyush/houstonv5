import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class PaletteGeneratorService {
  // Method to extract the vibrant color from an image URL
  Future<Color?> getVibrantColor(String imageUrl) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
      );
      return paletteGenerator.dominantColor?.color ?? Colors.grey;
    } catch (e) {
      debugPrint("Error generating palette: $e");
      return Colors.grey; // Default color if fetching fails
    }
  }
}
