import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Method to load the saved profile image path
Future<String?> loadProfileImage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profileImagePath');

    // Ensure the file still exists
    if (imagePath != null && File(imagePath).existsSync()) {
      return imagePath;
    }
  } catch (e) {
    debugPrint("Error loading profile image: $e");
  }
  return null;
}

/// Method to save the profile image path
Future<void> saveProfileImagePath(File? image) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (image != null) {
      await prefs.setString('profileImagePath', image.path);
    }
  } catch (e) {
    debugPrint("Error saving profile image path: $e");
  }
}

/// Method to remove the saved profile image path
Future<void> removeProfileImagePath() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profileImagePath');
  } catch (e) {
    debugPrint("Error removing profile image path: $e");
  }
}

/// Dialog to select, take, or delete a profile image
class PhotoUploadDialog extends StatefulWidget {
  final Function(File?) onImageSelected;
  final VoidCallback onDeleteImage;

  const PhotoUploadDialog({
    super.key,
    required this.onImageSelected,
    required this.onDeleteImage,
  });

  @override
  _PhotoUploadDialogState createState() => _PhotoUploadDialogState();
}

class _PhotoUploadDialogState extends State<PhotoUploadDialog> {
  final ImagePicker _picker = ImagePicker();

  /// Check permission and handle image source selection
  Future<void> _checkPermissionAndPickImage(ImageSource source) async {
    PermissionStatus status;

    if (source == ImageSource.camera) {
      status = await Permission.camera.request();
    } else {
      // Handle permissions for gallery
      if (Platform.isAndroid) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.photos.request();
      }
    }

    if (status.isGranted) {
      await _pickImage(source);
    } else {
      _showPermissionDeniedDialog(
          source == ImageSource.camera ? 'Camera' : 'Gallery');
    }
  }

  /// Pick image using ImagePicker
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        // Save the selected image path to SharedPreferences
        await saveProfileImagePath(File(pickedFile.path));

        // Call the callback with the new image file
        widget.onImageSelected(File(pickedFile.path));

        // Close the dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      _showErrorDialog();
    }
  }

  /// Show a dialog if permission is denied
  void _showPermissionDeniedDialog(String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content:
            Text('Please grant access to the $permission to pick an image.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Show an error dialog
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: const Text('Failed to pick an image. Please try again.'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Profile Picture'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Choose from the gallery'),
            onTap: () => _checkPermissionAndPickImage(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take a selfie'),
            onTap: () => _checkPermissionAndPickImage(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete picture'),
            onTap: () async {
              await removeProfileImagePath();
              widget.onImageSelected(null);
              widget.onDeleteImage();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
