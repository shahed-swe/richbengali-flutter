import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/oem_setup_service.dart';
import '../../theme/theme.dart';

/// Walks the user through the two device settings Android provides NO API for.
///
/// On Xiaomi/Redmi/Oppo/Realme/Vivo/Huawei/Tecno-style skins the OEM kills
/// backgrounded apps and blocks background window starts. Without these the app
/// simply cannot deliver anything once it is closed:
///   • no Autostart  → the OEM kills the app and it receives NO push at all
///   • no pop-up permission → an incoming call can't ring full-screen
/// Neither can be granted from code, so we explain them and open the exact page.
class CallSetupScreen extends StatefulWidget {
  const CallSetupScreen({super.key});

  @override
  State<CallSetupScreen> createState() => _CallSetupScreenState();
}

class _CallSetupScreenState extends State<CallSetupScreen> {
  final Set<int> _opened = {};

  Future<void> _open(int index, Future<bool> Function() action) async {
    await action();
    if (mounted) setState(() => _opened.add(index));
  }

  Future<void> _finish() async {
    await OemSetupService.markDone();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.brandPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.phoneCall,
                          color: AppColors.brandPink, size: 28),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Turn on calls & notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandPurple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your phone stops apps from running in the background. '
                      'Unless you turn these on, you will NOT get messages or '
                      'calls while RichBengali is closed.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StepCard(
                      index: 1,
                      done: _opened.contains(1),
                      icon: LucideIcons.rotateCw,
                      title: 'Allow Autostart',
                      body:
                          'Find RichBengali in the list and turn its switch ON. '
                          'Without this your phone shuts the app down and calls '
                          'never arrive.',
                      buttonLabel: 'Open Autostart',
                      onPressed: () =>
                          _open(1, OemSetupService.openAutostartSettings),
                    ),
                    const SizedBox(height: 14),
                    _StepCard(
                      index: 2,
                      done: _opened.contains(2),
                      icon: LucideIcons.appWindow,
                      title: 'Allow pop-up windows',
                      body:
                          'Turn ON "Display pop-up windows while running in the '
                          'background". This is what lets an incoming call show '
                          'full screen instead of a silent notification.',
                      buttonLabel: 'Open permissions',
                      onPressed: () =>
                          _open(2, OemSetupService.openBackgroundPopupSettings),
                    ),
                    const SizedBox(height: 14),
                    _StepCard(
                      index: 3,
                      done: _opened.contains(3),
                      icon: LucideIcons.batteryCharging,
                      title: 'Remove battery restrictions',
                      body:
                          'Choose "Don\'t restrict" / "No restrictions" so the '
                          'app can receive calls while your screen is off.',
                      buttonLabel: 'Open battery settings',
                      onPressed: () =>
                          _open(3, OemSetupService.openBatterySettings),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "I've done this",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.done,
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onPressed,
  });

  final int index;
  final bool done;
  final IconData icon;
  final String title;
  final String body;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF0FDF4) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? const Color(0xFF86EFAC) : AppColors.gray200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(done ? LucideIcons.circleCheck : icon,
                  size: 20,
                  color: done ? const Color(0xFF16A34A) : AppColors.brandPurple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$index. $title',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
                fontSize: 14, height: 1.4, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandPink,
                side: const BorderSide(color: AppColors.brandPink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                done ? 'Open again' : buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
