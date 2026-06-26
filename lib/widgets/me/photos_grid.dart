import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/me_repository.dart';
import '../../models/user.dart';
import '../../state/me_provider.dart';
import '../../theme/theme.dart';

/// 5-slot photo grid matching PhotosGrid.tsx
class PhotosGrid extends ConsumerStatefulWidget {
  const PhotosGrid({
    super.key,
    required this.photos,
    required this.onImagePress,
  });

  final List<UserPhoto> photos;
  final void Function(String url) onImagePress;

  @override
  ConsumerState<PhotosGrid> createState() => _PhotosGridState();
}

class _PhotosGridState extends ConsumerState<PhotosGrid> {
  final List<bool> _slotLoading = [false, false, false, false, false];
  final _picker = ImagePicker();
  bool _uploadingNew = false;
  static const int _maxPhotos = 5;

  List<UserPhoto> get _sorted {
    return [...widget.photos]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<String?> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    return file?.path;
  }

  void _setLoading(int idx, bool value) {
    if (!mounted) return;
    setState(() => _slotLoading[idx] = value);
  }

  Future<void> _handleAddPhotos() async {
    final remaining = _maxPhotos - widget.photos.length;
    if (remaining <= 0) return;

    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isEmpty) return;

    final toUpload = files.take(remaining).toList();
    final skipped = files.length - toUpload.length;

    if (!mounted) return;
    setState(() => _uploadingNew = true);
    var uploaded = 0;
    try {
      for (final f in toUpload) {
        await ref.read(meRepositoryProvider).uploadPhoto(f.path);
        uploaded++;
      }
      await ref.read(meProvider.notifier).refresh();
      if (mounted) {
        final msg = skipped > 0
            ? 'Uploaded $uploaded photo(s) — max $_maxPhotos, $skipped skipped'
            : 'Uploaded $uploaded photo(s)';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingNew = false);
    }
  }

  Future<void> _handleReplace(String photoId, int slotIndex) async {
    final path = await _pickImage();
    if (path == null) return;

    _setLoading(slotIndex, true);
    try {
      await ref.read(meRepositoryProvider).replacePhoto(photoId, path);
      await ref.read(meProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace photo: $e')),
        );
      }
    } finally {
      _setLoading(slotIndex, false);
    }
  }

  Future<void> _handleDelete(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(meRepositoryProvider).deletePhoto(photoId);
      await ref.read(meProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete photo')),
        );
      }
    }
  }

  Future<void> _handleSetPrimary(String photoId) async {
    try {
      await ref.read(meRepositoryProvider).setPrimaryPhoto(photoId);
      await ref.read(meProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primary photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update primary photo')),
        );
      }
    }
  }

  Future<void> _movePhoto(int from, int to) async {
    final sorted = _sorted;
    if (to < 0 || to >= sorted.length) return;
    final ids = sorted.map((p) => p.id).toList();
    final moved = ids.removeAt(from);
    ids.insert(to, moved);

    try {
      await ref.read(meRepositoryProvider).reorderPhotos(ids);
      await ref.read(meProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reorder photos')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    final slotWidth = (MediaQuery.of(context).size.width - 48 - 10) / 2;
    final canAddMore = sorted.length < _maxPhotos;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int i = 0; i < sorted.length; i++)
          if (_slotLoading[i])
            _buildLoadingSlot(slotWidth)
          else
            _buildFilledSlot(sorted[i], i, sorted.length, slotWidth),
        // Single multi-select "Add Photos" tile (replaces per-slot upload boxes)
        if (_uploadingNew)
          _buildLoadingSlot(slotWidth)
        else if (canAddMore)
          _buildAddSlot(slotWidth, _maxPhotos - sorted.length),
      ],
    );
  }

  Widget _buildLoadingSlot(double width) {
    return Container(
      width: width,
      height: 244,
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: AppRadius.border12,
        border: Border.all(color: AppColors.gray100),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPink),
        ),
      ),
    );
  }

  Widget _buildFilledSlot(UserPhoto photo, int idx, int totalPhotos, double width) {
    return Container(
      width: width,
      height: 244,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.border12,
        border: Border.all(color: AppColors.gray100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Image with camera overlay
            Stack(
              children: [
                GestureDetector(
                  onTap: () => widget.onImagePress(photo.url),
                  child: ClipRRect(
                    borderRadius: AppRadius.border8,
                    child: CachedNetworkImage(
                      imageUrl: photo.url,
                      width: double.infinity,
                      height: 110,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.gray100,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPink),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.gray100,
                        child: const Icon(LucideIcons.imageOff, color: AppColors.gray400),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _handleReplace(photo.id, idx),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppColors.brandPink,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(LucideIcons.camera, size: 12, color: AppColors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Delete button
            GestureDetector(
              onTap: () => _handleDelete(photo.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFfef2f2),
                  borderRadius: AppRadius.border8,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.trash2, size: 13, color: AppColors.danger),
                    SizedBox(width: 4),
                    Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Set primary button
            GestureDetector(
              onTap: () => _handleSetPrimary(photo.id),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: photo.isPrimary ? const Color(0xFFfbbf24) : AppColors.gray100,
                  borderRadius: AppRadius.border8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.star,
                      size: 13,
                      color: photo.isPrimary ? Colors.black : AppColors.gray500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      photo.isPrimary ? 'Primary' : 'Set Primary',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: photo.isPrimary ? Colors.black : AppColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Reorder buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: idx == 0 ? null : () => _movePhoto(idx, idx - 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: idx == 0 ? AppColors.gray50 : AppColors.gray100,
                        borderRadius: AppRadius.border8,
                      ),
                      child: Icon(
                        LucideIcons.chevronLeft,
                        size: 13,
                        color: idx == 0 ? AppColors.gray300 : AppColors.gray500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: idx == totalPhotos - 1 ? null : () => _movePhoto(idx, idx + 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: idx == totalPhotos - 1 ? AppColors.gray50 : AppColors.gray100,
                        borderRadius: AppRadius.border8,
                      ),
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 13,
                        color: idx == totalPhotos - 1 ? AppColors.gray300 : AppColors.gray500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSlot(double width, int remaining) {
    return GestureDetector(
      onTap: _handleAddPhotos,
      child: Container(
        width: width,
        height: 244,
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: AppRadius.border12,
          border: Border.all(color: AppColors.gray200, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.brandPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.plus,
                  size: 26, color: AppColors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add Photos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.gray700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'up to $remaining more',
              style: const TextStyle(fontSize: 11, color: AppColors.gray400),
            ),
          ],
        ),
      ),
    );
  }
}
