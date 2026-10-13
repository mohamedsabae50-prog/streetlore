import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../logic/auth_provider.dart';

class SuggestPlaceScreen extends StatefulWidget {
  const SuggestPlaceScreen({super.key});

  @override
  State<SuggestPlaceScreen> createState() => _SuggestPlaceScreenState();
}

class _SuggestPlaceScreenState extends State<SuggestPlaceScreen> {
  static const _mapCenter = LatLng(31.2001, 29.9187);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mapController = MapController();
  LatLng? _selectedLocation;
  Uint8List? _imageBytes;
  bool _isSubmitting = false;
  bool _isPickingLocation = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (error) {
      if (mounted) _showMessage('Could not select the image: $error');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isPickingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on location services and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is disabled. Enable it in app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() => _selectedLocation = location);
      _mapController.move(location, 15);
    } catch (error) {
      if (mounted) _showMessage('Could not get your location: $error');
    } finally {
      if (mounted) setState(() => _isPickingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final location = _selectedLocation;
    if (location == null) {
      _showMessage('Tap the map or use your current location first.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final client = SupabaseService.instance.clientOrNull;
    if (auth.userId.isEmpty || client == null) {
      _showMessage('Sign in to submit a place suggestion.');
      return;
    }
    final user = client.auth.currentUser;
    if (user == null || user.id != auth.userId) {
      _showMessage('Sign in to submit a place suggestion.');
      return;
    }

    setState(() => _isSubmitting = true);
    String? uploadedPath;
    try {
      String? imageUrl;
      final imageBytes = _imageBytes;
      if (imageBytes != null) {
        final compressedBytes = await FlutterImageCompress.compressWithList(
          imageBytes,
          minWidth: 1600,
          minHeight: 1600,
          quality: 82,
          format: CompressFormat.jpeg,
        );
        final storagePath = '${user.id}/${const Uuid().v4()}.jpg';
        await client.storage
            .from('suggestions')
            .uploadBinary(
              storagePath,
              compressedBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
        uploadedPath = storagePath;
        imageUrl = client.storage.from('suggestions').getPublicUrl(storagePath);
      }

      await client.from('suggested_places').insert({
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'lat': location.latitude,
        'lng': location.longitude,
        'image_url': imageUrl,
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your place suggestion was submitted.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (uploadedPath != null) {
        try {
          await client.storage.from('suggestions').remove([uploadedPath]);
        } catch (cleanupError) {
          debugPrint(
            'SuggestPlaceScreen: failed to clean up $uploadedPath: '
            '$cleanupError',
          );
        }
      }
      if (mounted) _showMessage('Could not submit your suggestion: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _selectedLocation;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Suggest a Hidden Gem'),
        backgroundColor: context.bgColor,
        foregroundColor: context.textPri,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                'Tell us about a place more travelers should discover.',
                style: TextStyle(color: context.textSec, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration(
                  context,
                  label: 'Place name',
                  icon: Icons.place_outlined,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a place name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                maxLength: 1500,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration(
                  context,
                  label: 'Description',
                  icon: Icons.notes_rounded,
                  hint: 'What makes this place special?',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add a short description.'
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Location',
                      style: TextStyle(
                        color: context.textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isPickingLocation ? null : _useCurrentLocation,
                    icon: _isPickingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Use current'),
                  ),
                ],
              ),
              Text(
                location == null
                    ? 'Tap the map to pin this place.'
                    : '${location.latitude.toStringAsFixed(5)}, '
                          '${location.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: context.textSec, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 270,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 11,
                      onTap: (_, point) =>
                          setState(() => _selectedLocation = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.streetlore.app',
                        maxZoom: 19,
                      ),
                      if (location != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: location,
                              width: 44,
                              height: 44,
                              child: const Icon(
                                Icons.location_pin,
                                color: AppColors.accent,
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('© OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Photo (optional)',
                style: TextStyle(
                  color: context.textPri,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _isSubmitting ? null : _pickImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: context.textSec,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose a photo',
                              style: TextStyle(color: context.textSec),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_imageBytes!, fit: BoxFit.cover),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: IconButton.filledTonal(
                                onPressed: () =>
                                    setState(() => _imageBytes = null),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Remove photo',
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit place'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: context.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.borderColor),
      ),
    );
  }
}
