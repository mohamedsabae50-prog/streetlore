import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../data/models/review_model.dart';
import '../../logic/review_provider.dart';
import '../../logic/auth_provider.dart';
import '../../core/constants/app_colors.dart';

class AddReviewSheet extends StatefulWidget {
  final String placeId;

  const AddReviewSheet({super.key, required this.placeId});

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _commentController = TextEditingController();
  double _rating = 5.0;
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (!mounted) return;
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please write a comment')));
      return;
    }

    setState(() => _isLoading = true);

    String? savedImagePath;

    if (_selectedImage != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imageName = '${DateTime.now().millisecondsSinceEpoch}.png';
      savedImagePath = '${directory.path}/$imageName';
      await _selectedImage!.copy(savedImagePath);
    }

    if (!mounted) return;

    
    
    final auth = context.read<AuthProvider>();
    final reviewProvider = context.read<ReviewProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userName = auth.userName.isNotEmpty
        ? auth.userName
        : 'Guest Traveler';

    final review = ReviewModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      placeId: widget.placeId,
      userName: userName,
      rating: _rating,
      comment: _commentController.text.trim(),
      imagePath: savedImagePath,
      date: DateTime.now(),
    );

    try {
      await reviewProvider.addReview(review);
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not post review: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Write a Review',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text('Rating: ', style: TextStyle(fontSize: 16)),
                Slider(
                  value: _rating,
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _rating.toString(),
                  onChanged: (val) => setState(() => _rating = val),
                ),
                Row(
                  children: [
                    Text('$_rating', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                  ],
                ),
              ],
            ),

            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add Photo'),
                ),
                const SizedBox(width: 16),
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post Review', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
