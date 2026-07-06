// ignore_for_file: deprecated_member_use
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user.dart';
import '../data/payouts_repository.dart';
import '../state/me_provider.dart';
import '../theme/theme.dart';

enum _Step { method, withdraw }
enum _MethodType { wallet, bank }

class PayoutModal extends ConsumerStatefulWidget {
  const PayoutModal({super.key, required this.me});

  final Me me;

  @override
  ConsumerState<PayoutModal> createState() => _PayoutModalState();
}

class _PayoutModalState extends ConsumerState<PayoutModal> {
  late _Step _step;
  _MethodType _methodType = _MethodType.wallet;

  // Method form controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _postCodeCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  String _currency = 'BDT';

  // Withdraw form
  final _amountCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _step = (widget.me.wiseRecipientId?.isNotEmpty == true)
        ? _Step.withdraw
        : _Step.method;

    // Pre-fill from wiseRecipientDetails if available
    final details = widget.me.wiseRecipientDetails;
    if (details != null) {
      _firstNameCtrl.text = details['firstName']?.toString() ?? '';
      _lastNameCtrl.text = details['lastName']?.toString() ?? '';
      _mobileCtrl.text = details['mobileNumber']?.toString() ?? '';
      _bankNameCtrl.text = details['bankCode']?.toString() ?? '';
      _accountNumberCtrl.text =
          details['accountNumber']?.toString() ??
          details['iban']?.toString() ??
          '';
      _cityCtrl.text = details['city']?.toString() ?? '';
      _postCodeCtrl.text = details['postCode']?.toString() ?? '';
      _streetCtrl.text = details['firstLine']?.toString() ?? '';
      _currency = details['currency']?.toString() ?? 'BDT';
      if (details['type']?.toString() == 'bank') {
        _methodType = _MethodType.bank;
      }
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _mobileCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _cityCtrl.dispose();
    _postCodeCtrl.dispose();
    _streetCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  bool _hasHtml(String s) => s.contains('<') || s.contains('>');

  Future<void> _handleSaveMethod() async {
    final fn = _firstNameCtrl.text.trim();
    final ln = _lastNameCtrl.text.trim();
    if (fn.isEmpty || ln.isEmpty || _hasHtml(fn) || _hasHtml(ln)) {
      _showAlert('Please enter a valid first and last name.');
      return;
    }
    if (_methodType == _MethodType.wallet) {
      final mobile = _mobileCtrl.text.trim();
      if (!mobile.startsWith('880')) {
        _showAlert('bKash number must start with 880.');
        return;
      }
    } else {
      final bn = _bankNameCtrl.text.trim();
      final an = _accountNumberCtrl.text.trim();
      if (bn.isEmpty || an.isEmpty || _hasHtml(bn) || _hasHtml(an)) {
        _showAlert('Please enter valid bank details.');
        return;
      }
    }
    final city = _cityCtrl.text.trim();
    final post = _postCodeCtrl.text.trim();
    final street = _streetCtrl.text.trim();
    if (city.isEmpty || post.isEmpty || street.isEmpty ||
        _hasHtml(city) || _hasHtml(post) || _hasHtml(street)) {
      _showAlert('Please fill in all address fields.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Backend methodSchema requires details.accountHolderName and a NESTED
      // details.address { country, city, postCode, firstLine }. (Matches
      // richb-rn PayoutModal — country defaults to 'BD'.)
      final Map<String, dynamic> details = {
        'accountHolderName': '$fn $ln'.trim(),
        'firstName': fn,
        'lastName': ln,
        'currency': _currency,
        if (_methodType == _MethodType.wallet)
          'mobileNumber': _mobileCtrl.text.trim()
        else ...<String, dynamic>{
          'bankCode': _bankNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'iban': _accountNumberCtrl.text.trim(),
        },
        'address': {
          'country': 'BD',
          'city': city,
          'postCode': post,
          'firstLine': street,
        },
      };
      await ref.read(payoutsRepositoryProvider).setMethod(
            currency: _currency,
            type: _methodType == _MethodType.wallet ? 'wallet' : 'bank',
            details: details,
          );
      await ref.read(meProvider.notifier).refresh();
      if (mounted) setState(() => _step = _Step.withdraw);
    } catch (e) {
      _showAlert(_payoutError(e, 'Failed to save method. Please try again.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleWithdraw() async {
    final amountStr = _amountCtrl.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;
    final balance = widget.me.walletBalanceUsd ?? 0;
    final minCap = widget.me.minWithdrawalCap ?? 10.0;

    if (amount < minCap) {
      _showAlert('Minimum withdrawal is \$${minCap.toStringAsFixed(2)}.');
      return;
    }
    if (amount > balance) {
      _showAlert('Amount exceeds your available balance.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url =
          await ref.read(payoutsRepositoryProvider).requestPayout(amountUsd: amount);
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showAlert('Withdrawal request submitted successfully!');
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showAlert(_payoutError(e, 'Failed to request payout. Please try again.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _payoutError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        if (data['missingFields'] is List &&
            (data['missingFields'] as List).isNotEmpty) {
          return 'Missing: ${(data['missingFields'] as List).join(', ')}';
        }
        final m = data['error'] ?? data['message'];
        if (m != null && m.toString().isNotEmpty) return m.toString();
      }
    }
    return fallback;
  }

  void _showAlert(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMethod = _step == _Step.method;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.payoutModal,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMethod
                            ? 'SECURE YOUR EARNINGS'
                            : 'TRANSFER TO YOUR ACCOUNT',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xB3FFFFFF),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isMethod ? 'Payout Setup' : 'Withdraw Funds',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),

          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isMethod ? _buildMethodStep() : _buildWithdrawStep(),
            ),
          ),

          // Footer
          _buildFooter(isMethod),
        ],
      ),
    );
  }

  Widget _buildMethodStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set up your payout method to receive earnings.',
          style: TextStyle(fontSize: 13, color: AppColors.gray500),
        ),
        const SizedBox(height: 16),

        // Toggle: bKash / Bank
        Row(
          children: [
            _methodToggle('bKash (Wallet)', _MethodType.wallet),
            const SizedBox(width: 8),
            _methodToggle('Bank Account', _MethodType.bank),
          ],
        ),
        const SizedBox(height: 16),

        // First + Last name
        Row(
          children: [
            Expanded(child: _field(_firstNameCtrl, 'First Name')),
            const SizedBox(width: 8),
            Expanded(child: _field(_lastNameCtrl, 'Last Name')),
          ],
        ),
        const SizedBox(height: 12),

        if (_methodType == _MethodType.wallet) ...[
          _field(
            _mobileCtrl,
            'bKash Number (e.g. 88017...)',
            inputType: TextInputType.phone,
          ),
        ] else ...[
          // Currency select
          DropdownButtonFormField<String>(
            value: _currency,
            decoration: _inputDecoration('Currency'),
            items: ['BDT', 'USD', 'EUR', 'GBP']
                .map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _currency = v);
            },
          ),
          const SizedBox(height: 12),
          _field(_bankNameCtrl, 'Bank Name'),
          const SizedBox(height: 12),
          _field(_accountNumberCtrl, 'Account Number / IBAN'),
        ],
        const SizedBox(height: 16),

        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'RESIDENTIAL ADDRESS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _field(_cityCtrl, 'City'),
        const SizedBox(height: 12),
        _field(
          _postCodeCtrl,
          'Postal Code',
          inputType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _field(_streetCtrl, 'Street Address'),
      ],
    );
  }

  Widget _buildWithdrawStep() {
    final details = widget.me.wiseRecipientDetails;
    final displayName = details?['display']?.toString() ??
        details?['firstName']?.toString();
    final balance = widget.me.walletBalanceUsd ?? 0;
    final minCap = widget.me.minWithdrawalCap ?? 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Method info card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBlue,
            border: Border.all(color: AppColors.cardBlue100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LINKED METHOD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray500,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              if (displayName != null) ...[
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPink,
                  ),
                ),
                if (details?['type'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${details!['type']} · ${details['currency'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ] else
                const Text(
                  'No method linked',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.gray500,
                  ),
                ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _step = _Step.method),
                child: const Text(
                  'Change Method',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Amount input
        TextFormField(
          controller: _amountCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: _inputDecoration('Amount').copyWith(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Available Balance: \$${balance.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 12, color: AppColors.gray500),
        ),
        const SizedBox(height: 12),

        // Note card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardAmber,
            border: Border.all(color: AppColors.cardAmber100),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Minimum withdrawal: \$${minCap.toStringAsFixed(2)}. '
            'Admin will review and process within 2–5 business days.',
            style: const TextStyle(fontSize: 12, color: AppColors.gray700),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isMethod) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed:
                  _isLoading ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(0, 48),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.gray500),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : (isMethod ? _handleSaveMethod : _handleWithdraw),
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFecfdf5),
                side: BorderSide(
                  color: AppColors.emerald500.withValues(alpha: 0.2),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(0, 48),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.emerald700,
                        ),
                      ),
                    )
                  : Text(
                      isMethod ? 'Save Method' : 'Confirm',
                      style: const TextStyle(
                        color: AppColors.emerald700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodToggle(String label, _MethodType type) {
    final active = _methodType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _methodType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.brandPink : Colors.transparent,
            border: Border.all(
              color: active ? AppColors.brandPink : AppColors.border200,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.gray500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType inputType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.gray500),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.brandPink, width: 1.5),
      ),
    );
  }
}

/// Convenience: show the modal as a dialog (not bottom sheet, to match RN modal).
Future<void> showPayoutModal(BuildContext context, Me me) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => PayoutModal(me: me),
  );
}
