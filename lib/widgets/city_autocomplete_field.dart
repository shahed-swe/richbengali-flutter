import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/places_service.dart';
import '../theme/theme.dart';

/// A searchable city input backed by OpenStreetMap Nominatim.
///
/// Free-typing still works as a fallback (each keystroke calls [onChanged]),
/// but tapping a suggestion sets the field to a standardized city name and
/// calls [onChanged] with that value — encouraging consistent values that
/// match the backend's prefix search.
class CityAutocompleteField extends ConsumerStatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.onChanged,
    this.initialValue,
    this.label,
    this.hint,
    this.errorText,
    this.style = CityAutocompleteFieldStyle.boxed,
  });

  /// Initial text to seed the field with (e.g. the user's current city).
  final String? initialValue;

  /// Called with the current city value — on manual edits and on suggestion pick.
  final ValueChanged<String> onChanged;

  final String? label;
  final String? hint;
  final String? errorText;

  /// Which of the app's two existing input decorations to mimic.
  final CityAutocompleteFieldStyle style;

  @override
  ConsumerState<CityAutocompleteField> createState() => _CityAutocompleteFieldState();
}

/// Matches the two distinct input looks already used by register/me screens.
enum CityAutocompleteFieldStyle {
  /// Register screen's `_InputField`: filled gray100 box, no visible border unless error.
  boxed,

  /// Me screen's `_FormField`: filled gray50 box with an OutlineInputBorder.
  outlined,
}

class _CityAutocompleteFieldState extends ConsumerState<CityAutocompleteField> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  Timer? _debounce;
  CancelToken? _cancelToken;

  List<PlaceSuggestion> _suggestions = [];
  bool _loading = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant CityAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-seed if the parent hands us a new initial value (e.g. profile loaded later)
    // and the user hasn't already typed something of their own.
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != null &&
        _controller.text.isEmpty) {
      _controller.text = widget.initialValue!;
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Give tap-on-suggestion a chance to register before hiding.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _showSuggestions = false);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    widget.onChanged(value);

    _debounce?.cancel();
    _cancelToken?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _loading = false;
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _showSuggestions = true;
    });

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final cancelToken = CancelToken();
      _cancelToken = cancelToken;
      final results = await ref.read(placesServiceProvider).searchCities(query, cancelToken: cancelToken);
      if (!mounted || cancelToken.isCancelled) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  void _selectSuggestion(PlaceSuggestion suggestion) {
    _controller.text = suggestion.city;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    widget.onChanged(suggestion.city);
    _focusNode.unfocus();
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(),
        if (_showSuggestions) _buildSuggestionsPanel(),
      ],
    );
  }

  Widget _buildField() {
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onTextChanged,
      style: AppTextStyles.textBase.copyWith(color: AppColors.gray900),
      decoration: _decoration(),
    );

    switch (widget.style) {
      case CityAutocompleteFieldStyle.boxed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null && widget.label!.isNotEmpty) ...[
              Text(
                widget.label!,
                style: AppTextStyles.textSm.copyWith(color: AppColors.gray700, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
            ],
            Container(
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: AppRadius.border8,
                border: widget.errorText != null ? Border.all(color: AppColors.danger) : null,
              ),
              child: field,
            ),
            if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.errorText!, style: AppTextStyles.textXs.copyWith(color: AppColors.danger)),
            ],
          ],
        );
      case CityAutocompleteFieldStyle.outlined:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null && widget.label!.isNotEmpty) ...[
              Text(widget.label!, style: AppTextStyles.textSm.copyWith(color: AppColors.gray700)),
              const SizedBox(height: 4),
            ],
            field,
          ],
        );
    }
  }

  InputDecoration _decoration() {
    final trailing = _loading
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandPink),
            ),
          )
        : null;

    switch (widget.style) {
      case CityAutocompleteFieldStyle.boxed:
        return InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: const Icon(LucideIcons.mapPin, size: 18, color: AppColors.gray400),
          suffixIcon: trailing,
          hintText: widget.hint,
          hintStyle: AppTextStyles.textBase.copyWith(color: AppColors.gray400),
        );
      case CityAutocompleteFieldStyle.outlined:
        final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
        final borderColor = hasError ? AppColors.danger : AppColors.gray200;
        return InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: AppColors.gray50,
          suffixIcon: trailing,
          border: OutlineInputBorder(
            borderRadius: AppRadius.border12,
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.border12,
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.border12,
            borderSide: BorderSide(color: hasError ? AppColors.danger : AppColors.brandPink),
          ),
          errorText: hasError ? widget.errorText : null,
        );
    }
  }

  Widget _buildSuggestionsPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppRadius.border12,
        border: Border.all(color: AppColors.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _loading && _suggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandPink),
                ),
              ),
            )
          : _suggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Text(
                    'No matches',
                    style: AppTextStyles.textSm.copyWith(color: AppColors.gray500),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.gray100),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return InkWell(
                      onTap: () => _selectSuggestion(suggestion),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.mapPin, size: 14, color: AppColors.gray400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestion.city,
                                    style: AppTextStyles.textSm.copyWith(
                                      color: AppColors.gray900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (suggestion.displayName != suggestion.city)
                                    Text(
                                      suggestion.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.textXs.copyWith(color: AppColors.gray500),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
