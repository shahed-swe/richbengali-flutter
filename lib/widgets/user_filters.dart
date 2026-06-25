import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../state/users_provider.dart';
import '../theme/theme.dart';

class UserFiltersButton extends ConsumerWidget {
  const UserFiltersButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(userFiltersProvider);
    final hasActive = filters.hasActiveFilters;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _showFilterSheet(context, ref, filters),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.slidersHorizontal,
                  size: 14,
                  color: AppColors.gray700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasActive) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(userFiltersProvider.notifier).clear(),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFfef2f2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(LucideIcons.x, size: 16, color: AppColors.danger),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, UserFilters current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(current: current, outerRef: ref),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.current, required this.outerRef});
  final UserFilters current;
  final WidgetRef outerRef;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _minAgeCtrl;
  late final TextEditingController _maxAgeCtrl;

  @override
  void initState() {
    super.initState();
    _cityCtrl =
        TextEditingController(text: widget.current.cityStartsWith ?? '');
    _minAgeCtrl = TextEditingController(
      text: widget.current.minAge != null ? '${widget.current.minAge}' : '',
    );
    _maxAgeCtrl = TextEditingController(
      text: widget.current.maxAge != null ? '${widget.current.maxAge}' : '',
    );
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _minAgeCtrl.dispose();
    _maxAgeCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final city = _cityCtrl.text.trim();
    final minAge = int.tryParse(_minAgeCtrl.text.trim());
    final maxAge = int.tryParse(_maxAgeCtrl.text.trim());
    widget.outerRef.read(userFiltersProvider.notifier).apply(UserFilters(
          cityStartsWith: city.isEmpty ? null : city,
          minAge: minAge,
          maxAge: maxAge,
        ));
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.outerRef.read(userFiltersProvider.notifier).clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = widget.current.hasActiveFilters;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Users',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // City
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'City',
                style: TextStyle(color: AppColors.gray500, fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            _InputField(controller: _cityCtrl, hint: 'Dhaka...'),
            const SizedBox(height: 16),

            // Age row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Min Age',
                        style:
                            TextStyle(color: AppColors.gray500, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      _InputField(
                          controller: _minAgeCtrl,
                          hint: '18',
                          numeric: true),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Max Age',
                        style:
                            TextStyle(color: AppColors.gray500, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      _InputField(
                          controller: _maxAgeCtrl,
                          hint: '60',
                          numeric: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.gray300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
            if (hasActive) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _clear,
                child: Center(
                  child: Text(
                    'Clear Filters',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.numeric = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Color(0xFF1f2937), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9ca3af)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.brandPurple),
        ),
      ),
    );
  }
}
