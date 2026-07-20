import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_image.dart';
import '../../data/models/review_model.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../../logic/review_provider.dart';

class AddReviewSheet extends StatefulWidget {
  final String placeId;

  const AddReviewSheet({super.key, required this.placeId});

  @override
  State<AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends State<AddReviewSheet> {
  final _commentController = TextEditingController();
  double _rating = 5.0;
  String? _imageDataUri;
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (!mounted || pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;
    setState(() => _imageDataUri = AppImage.toDataUri(bytes));
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('review_empty_warn'))));
      return;
    }

    setState(() => _isLoading = true);

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
      userId: auth.currentUserId,
      rating: _rating,
      comment: _commentController.text.trim(),
      imagePath: _imageDataUri,
      date: DateTime.now(),
    );

    try {
      await reviewProvider.addReview(review);
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(content: Text('${context.tr('review_failed')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPri = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('write_review'),
                style: TextStyle(
                  color: textPri,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text(
                    '${context.tr('rating_label')}: ',
                    style: TextStyle(color: textPri, fontSize: 15),
                  ),
                  Expanded(
                    child: Slider(
                      value: _rating,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: _rating.toStringAsFixed(0),
                      onChanged: (val) => setState(() => _rating = val),
                    ),
                  ),
                  Text(
                    _rating.toStringAsFixed(0),
                    style: TextStyle(
                      color: textPri,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 18),
                ],
              ),

              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.tr('review_hint'),
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
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: Text(context.tr('add_photo_btn')),
                  ),
                  const SizedBox(width: 16),
                  if (_imageDataUri != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppImage(
                        source: _imageDataUri!,
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
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          context.tr('post_review'),
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
