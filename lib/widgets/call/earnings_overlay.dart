import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/json_parse.dart';
import '../../models/user.dart';
import '../../services/socket_service.dart';
import '../../theme/theme.dart';

/// Mirrors EarningsOverlay.tsx â€” blurred pill showing live earnings (female)
/// or remaining balance minutes (male) during an ongoing call.
class EarningsOverlay extends ConsumerStatefulWidget {
  const EarningsOverlay({super.key, required this.me, this.durationSeconds = 0});

  final Me me;

  /// Live call duration in seconds. Female live earnings are computed on-device
  /// ($10/hour) from this, since the backend does not push live earnings.
  final int durationSeconds;

  @override
  ConsumerState<EarningsOverlay> createState() => _EarningsOverlayState();
}

class _EarningsOverlayState extends ConsumerState<EarningsOverlay> {
  StreamSubscription<Map<String, dynamic>>? _sub;

  // Female per-hour earning rate. Live earnings are computed on-device from the
  // call duration; a backend earnings:update (if any) overrides when higher.
  static const double _femaleRatePerHourUsd = 10.0;

  double _backendEarnings = 0.0;
  double? _liveMaleBalance;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(socketServiceProvider).onEarningsUpdate.listen((payload) {
      if (!mounted) return;
      setState(() {
        // Backend startCallTicker sends snake_case keys with a _usd suffix.
        final earn = asDoubleN(payload['call_earnings_usd'] ??
                payload['callEarnings'] ??
                payload['earnings']) ??
            0.0;
        _backendEarnings = earn;
        final maleBal = payload['male_balance_usd'] ?? payload['maleBalance'];
        if (maleBal != null) {
          _liveMaleBalance = asDoubleN(maleBal);
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

    // Live earnings = call minutes × $10/hour, computed on-device so the value
    // ticks up every second. If the backend ever pushes a higher figure, use it.
    final computedEarnings =
        widget.durationSeconds / 3600.0 * _femaleRatePerHourUsd;
    final earnings = math.max(computedEarnings, _backendEarnings);
    final valueText = isFemale
        ? '\$${earnings.toStringAsFixed(2)}'
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

