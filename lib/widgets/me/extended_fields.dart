import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/refs_repository.dart';
import '../../models/ref_option.dart';
import '../../theme/theme.dart';

/// Async provider that fetches a ref list by type, caching per type string.
final _refProvider = FutureProvider.family<List<RefOption>, String>((ref, type) {
  return ref.read(refsRepositoryProvider).getRefs(type);
});

/// Extended profile fields — height/weight inputs, chip selectors for
/// looking_for, education_level, religion, languages (multi), interests (multi),
/// drinking/smoking toggles.
///
/// Reads initial values via [initialValues] and reports all changes via
/// [onChanged], which receives the current extended-field patch map.
class ExtendedFields extends ConsumerStatefulWidget {
  const ExtendedFields({
    super.key,
    required this.initialValues,
    required this.onChanged,
  });

  /// Initial values for the extended fields (subset of profile Map).
  final Map<String, dynamic> initialValues;

  /// Called whenever any field changes; passes the full extended-fields map.
  final void Function(Map<String, dynamic> values) onChanged;

  @override
  ConsumerState<ExtendedFields> createState() => _ExtendedFieldsState();
}

class _ExtendedFieldsState extends ConsumerState<ExtendedFields> {
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _workCtrl;
  late final TextEditingController _educationCtrl;

  String? _lookingFor;
  String? _educationLevel;
  String? _drinking;
  String? _smoking;
  String? _religion;
  List<String> _languages = [];
  List<String> _interests = [];

  static const _drinkingOptions = ['no', 'socially', 'often'];
  static const _smokingOptions = ['no', 'occasionally', 'regularly'];

  @override
  void initState() {
    super.initState();
    final v = widget.initialValues;
    _heightCtrl = TextEditingController(
        text: v['height_cm'] != null ? v['height_cm'].toString() : '');
    _weightCtrl = TextEditingController(
        text: v['weight_kg'] != null ? v['weight_kg'].toString() : '');
    _workCtrl = TextEditingController(text: (v['work'] ?? '').toString());
    _educationCtrl = TextEditingController(text: (v['education'] ?? '').toString());
    _lookingFor = v['looking_for']?.toString();
    _educationLevel = v['education_level']?.toString();
    _drinking = v['drinking']?.toString();
    _smoking = v['smoking']?.toString();
    _religion = v['religion']?.toString();
    _languages = _parseList(v['languages']);
    _interests = _parseList(v['interests']);
  }

  List<String> _parseList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _workCtrl.dispose();
    _educationCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged({
      'height_cm': _heightCtrl.text.isEmpty
          ? null
          : int.tryParse(_heightCtrl.text),
      'weight_kg': _weightCtrl.text.isEmpty
          ? null
          : int.tryParse(_weightCtrl.text),
      'work': _workCtrl.text,
      'education': _educationCtrl.text,
      'looking_for': _lookingFor,
      'education_level': _educationLevel,
      'drinking': _drinking,
      'smoking': _smoking,
      'religion': _religion,
      'languages': _languages,
      'interests': _interests,
    });
  }

  bool _hasTags(String v) => RegExp(r'<[^>]*>?').hasMatch(v);

  @override
  Widget build(BuildContext context) {
    final lookingForAsync = ref.watch(_refProvider('looking_for'));
    final eduLevelAsync = ref.watch(_refProvider('education_level'));
    final religionAsync = ref.watch(_refProvider('religion'));
    final langAsync = ref.watch(_refProvider('language'));
    final interestAsync = ref.watch(_refProvider('interest'));

    final isLoading = [lookingForAsync, eduLevelAsync, religionAsync, langAsync, interestAsync]
        .any((a) => a.isLoading);

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandPink),
          ),
        ),
      );
    }

    final lookingForOptions = lookingForAsync.asData?.value ?? [];
    final eduLevelOptions = eduLevelAsync.asData?.value ?? [];
    final religionOptions = religionAsync.asData?.value ?? [];
    final languageOptions = langAsync.asData?.value ?? [];
    final interestOptions = interestAsync.asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Height & Weight row
        Row(
          children: [
            Expanded(child: _buildTextField(
              label: 'Height (cm)',
              controller: _heightCtrl,
              keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildTextField(
              label: 'Weight (kg)',
              controller: _weightCtrl,
              keyboardType: TextInputType.number,
            )),
          ],
        ),
        const SizedBox(height: 14),

        // Work
        _buildTextField(
          label: 'Work',
          controller: _workCtrl,
          hasTagError: _hasTags(_workCtrl.text),
        ),
        const SizedBox(height: 14),

        // Education
        _buildTextField(
          label: 'Education',
          controller: _educationCtrl,
          hasTagError: _hasTags(_educationCtrl.text),
        ),
        const SizedBox(height: 14),

        // Looking For (single-select horizontal scroll)
        if (lookingForOptions.isNotEmpty) ...[
          _buildSectionLabel('Looking For'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: lookingForOptions.map((o) => _buildChip(
                label: o.label,
                selected: _lookingFor == o.slug,
                onTap: () => setState(() {
                  _lookingFor = o.slug;
                  _notify();
                }),
                margin: const EdgeInsets.only(right: 8),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Education Level (single-select horizontal scroll)
        if (eduLevelOptions.isNotEmpty) ...[
          _buildSectionLabel('Education Level'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: eduLevelOptions.map((o) => _buildChip(
                label: o.label,
                selected: _educationLevel == o.slug,
                onTap: () => setState(() {
                  _educationLevel = o.slug;
                  _notify();
                }),
                margin: const EdgeInsets.only(right: 8),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Drinking (single-select row)
        _buildSectionLabel('Drinking'),
        const SizedBox(height: 6),
        Row(
          children: _drinkingOptions.map((v) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: v != _drinkingOptions.last ? 6 : 0,
              ),
              child: _buildChip(
                label: _capitalize(v),
                selected: _drinking == v,
                onTap: () => setState(() {
                  _drinking = v;
                  _notify();
                }),
                expand: true,
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 14),

        // Smoking (single-select row)
        _buildSectionLabel('Smoking'),
        const SizedBox(height: 6),
        Row(
          children: _smokingOptions.map((v) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: v != _smokingOptions.last ? 6 : 0,
              ),
              child: _buildChip(
                label: _capitalize(v),
                selected: _smoking == v,
                onTap: () => setState(() {
                  _smoking = v;
                  _notify();
                }),
                expand: true,
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 14),

        // Religion (single-select horizontal scroll)
        if (religionOptions.isNotEmpty) ...[
          _buildSectionLabel('Religion'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: religionOptions.map((o) => _buildChip(
                label: o.label,
                selected: _religion == o.slug,
                onTap: () => setState(() {
                  _religion = o.slug;
                  _notify();
                }),
                margin: const EdgeInsets.only(right: 8),
              )).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Languages (multi-select wrap)
        if (languageOptions.isNotEmpty) ...[
          _buildSectionLabel('Languages'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: languageOptions.map((o) {
              final selected = _languages.contains(o.slug);
              return _buildChip(
                label: o.label,
                selected: selected,
                onTap: () => setState(() {
                  if (selected) {
                    _languages = [..._languages]..remove(o.slug);
                  } else {
                    _languages = [..._languages, o.slug];
                  }
                  _notify();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // Interests (multi-select wrap)
        if (interestOptions.isNotEmpty) ...[
          _buildSectionLabel('Interests'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: interestOptions.map((o) {
              final selected = _interests.contains(o.slug);
              return _buildChip(
                label: o.label,
                selected: selected,
                onTap: () => setState(() {
                  if (selected) {
                    _interests = [..._interests]..remove(o.slug);
                  } else {
                    _interests = [..._interests, o.slug];
                  }
                  _notify();
                }),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.gray700,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool hasTagError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.gray700,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) {
            setState(() {});
            _notify();
          },
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppColors.gray50,
            border: OutlineInputBorder(
              borderRadius: AppRadius.border8,
              borderSide: BorderSide(
                color: hasTagError ? AppColors.danger : AppColors.gray200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.border8,
              borderSide: BorderSide(
                color: hasTagError ? AppColors.danger : AppColors.gray200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.border8,
              borderSide: BorderSide(
                color: hasTagError ? AppColors.danger : AppColors.brandPink,
              ),
            ),
            errorText: hasTagError ? 'HTML/Script tags not allowed' : null,
            suffixIcon: hasTagError
                ? const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 16)
                : null,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    EdgeInsetsGeometry? margin,
    bool expand = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPink : AppColors.gray100,
          borderRadius: AppRadius.borderFull,
        ),
        alignment: expand ? Alignment.center : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  String _capitalize(String v) {
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }
}
