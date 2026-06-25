import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/user.dart';
import '../../services/socket_service.dart';
import '../../theme/theme.dart';

/// Mirrors EarningsOverlay.tsx â€” blurred pill showing live earnings (female)
/// or remaining balance minutes (male) during an ongoing call.
class EarningsOverlay extends ConsumerStatefulWidget {
  const EarningsOverlay({super.key, required this.me});

  final Me me;

  @override
  ConsumerState<EarningsOverlay> createState() => _EarningsOverlayState();
}

class _EarningsOverlayState extends ConsumerState<EarningsOverlay> {
  StreamSubscription<Map<String, dynamic>>? _sub;

  String _callEarnings = '0.00';
  double? _liveMaleBalance;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(socketServiceProvider).onEarningsUpdate.listen((payload) {
      if (!mounted) return;
      setState(() {
        _callEarnings =
            (payload['callEarnings'] ?? payload['earnings'] ?? '0.00')
                .toString();
        if (payload['maleBalance'] != null) {
          _liveMaleBalance =
              (payload['maleBalance'] as num).toDouble();
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  int _displayMinutes() {
    final me = widget.me;
    final baseBalance = me.walletBalanceUsd ?? 0.0;
    final baseMinutes = me.availableCallMinutes ?? 0.0;
    if (_liveMaleBalance != null && baseMinutes > 0 && baseBalance > 0) {
      return ((_liveMaleBalance! / (baseBalance / baseMinutes))).floor();
    }
    return (me.availableCallMinutes ?? 0).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final isFemale = !widget.me.isMale;
    final iconColor = isFemale ? AppColors.brandPink : const Color(0xFF15803d);

    final valueText = isFemale
        ? '\$$_callEarnings'
        : '${_displayMinutes()}';
    final labelText = isFemale ? 'Earnings' : 'mins';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wallet, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            valueText,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            labelText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

