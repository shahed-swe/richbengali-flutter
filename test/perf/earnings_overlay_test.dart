import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richbengali/models/user.dart';
import 'package:richbengali/services/socket_service.dart';
import 'package:richbengali/widgets/call/earnings_overlay.dart';

/// Counts how often its subtree's *parent* rebuilds, so we can prove a duration
/// tick does not propagate upward into the call screen.
class _RebuildCounter extends StatefulWidget {
  const _RebuildCounter({required this.child, required this.onBuild});

  final Widget child;
  final VoidCallback onBuild;

  @override
  State<_RebuildCounter> createState() => _RebuildCounterState();
}

class _RebuildCounterState extends State<_RebuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return widget.child;
  }
}

void main() {
  testWidgets(
    'a duration tick repaints the earnings value without rebuilding the parent',
    (tester) async {
      final duration = ValueNotifier<int>(0);
      addTearDown(duration.dispose);

      // Female user: earnings are computed on-device from the duration.
      const me = Me(id: '1', name: 'A', gender: 'female');

      var parentBuilds = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socketServiceProvider.overrideWithValue(SocketService()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: _RebuildCounter(
                onBuild: () => parentBuilds++,
                child: EarningsOverlay(me: me, duration: duration),
              ),
            ),
          ),
        ),
      );

      expect(find.text('\$0.00'), findsOneWidget);
      final buildsAfterFirstFrame = parentBuilds;

      // 18 minutes at $10/hour = $3.00.
      duration.value = 18 * 60;
      await tester.pump();

      expect(
        find.text('\$3.00'),
        findsOneWidget,
        reason: 'the earnings value must follow the duration notifier',
      );
      expect(
        parentBuilds,
        buildsAfterFirstFrame,
        reason:
            'a once-a-second tick must not rebuild anything above the value '
            'text; it used to setState the whole call screen, rebuilding the '
            'Agora video views and every control once per second',
      );
    },
  );
}
