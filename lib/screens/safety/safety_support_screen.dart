import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/users_repository.dart';
import '../../theme/theme.dart';

/// Safety & Support — the way in that does not depend on anybody else.
///
/// Reporting already exists on a profile and inside a chat, which covers a user
/// who has somebody to report and nobody else. Somebody who has just signed up,
/// matched with no one and opened no chats, previously had no way to tell us
/// anything: the only always-visible rows in Settings were Terms and Privacy,
/// and both of those open a browser. Google Play's Child Safety Standards
/// policy asks for a mechanism that is always reachable and that keeps the user
/// inside the app, and rejected 2.0.12 for not having one.
///
/// So this screen does two things and neither of them leaves the app: it takes
/// a message, and it states the standards in full rather than linking out to
/// them.
class SafetySupportScreen extends ConsumerStatefulWidget {
  const SafetySupportScreen({super.key});

  @override
  ConsumerState<SafetySupportScreen> createState() => _SafetySupportScreenState();
}

class _SafetySupportScreenState extends ConsumerState<SafetySupportScreen> {
  /// Same categories the profile/chat report sheet offers, so both routes land
  /// in the moderation queue speaking one vocabulary.
  static const _reasons = <MapEntry<String, String>>[
    MapEntry('child_safety', 'Child safety concern'),
    MapEntry('harassment', 'Harassment or abuse'),
    MapEntry('nudity_sexual', 'Nudity or sexual content'),
    MapEntry('spam_scam', 'Spam or scam'),
    MapEntry('fake_profile', 'Fake profile'),
    MapEntry('other', 'Something else'),
  ];

  String _reason = 'child_safety';
  final _detailsCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = _detailsCtrl.text.trim();
    if (details.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(usersRepositoryProvider)
          .sendFeedback(reason: _reason, details: details);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sending = false;
      });
      _detailsCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_sent) _buildSentCard() else _buildForm(),
                    const SizedBox(height: 24),
                    _buildStandards(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(LucideIcons.arrowLeft,
                  size: 20, color: AppColors.gray700),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Safety & Support',
            style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray900),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report a problem',
          style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray800),
        ),
        const SizedBox(height: 4),
        Text(
          'Tell us what happened and we will look into it. You do not need to '
          'know who was involved — send this even if you just want to flag '
          'something.',
          style: AppTextStyles.textSm.copyWith(color: AppColors.gray500),
        ),
        const SizedBox(height: 16),
        ..._reasons.map(
          (e) => RadioListTile<String>(
            value: e.key,
            groupValue: _reason,
            onChanged: _sending ? null : (v) => setState(() => _reason = v!),
            title: Text(
              e.value,
              style: AppTextStyles.textBase.copyWith(color: AppColors.gray800),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.rose500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _detailsCtrl,
          maxLines: 5,
          maxLength: 2000,
          enabled: !_sending,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Describe what happened…',
            border: OutlineInputBorder(borderRadius: AppRadius.border12),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rose500,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.border12),
            ),
            onPressed: _detailsCtrl.text.trim().isEmpty || _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send'),
          ),
        ),
      ],
    );
  }

  Widget _buildSentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFf0fdf4),
        borderRadius: AppRadius.border12,
        border: Border.all(color: const Color(0xFFbbf7d0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.circleCheck,
                  size: 18, color: Color(0xFF15803d)),
              const SizedBox(width: 8),
              Text(
                'Thanks — we have got it',
                style:
                    AppTextStyles.textBaseBold.copyWith(color: const Color(0xFF15803d)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Our team reviews every report. Child safety reports are treated as '
            'the highest priority.',
            style: AppTextStyles.textSm.copyWith(color: const Color(0xFF166534)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _sent = false),
            child: Text(
              'Send another',
              style: AppTextStyles.textSmBold.copyWith(color: AppColors.rose500),
            ),
          ),
        ],
      ),
    );
  }

  /// The published standards, stated here rather than linked.
  ///
  /// A link would open a browser, which is the thing the policy rules out. The
  /// wording tracks the published page at
  /// richbengali.com's child-safety-standards; if one changes the other has to.
  Widget _buildStandards() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: AppRadius.border12,
        border: Border.all(color: AppColors.border100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Child Safety Standards',
            style: AppTextStyles.textLgBold.copyWith(color: AppColors.gray800),
          ),
          const SizedBox(height: 8),
          _para(
            'RichBengali is an adults-only (18+) app. We have zero tolerance for '
            'child sexual abuse and exploitation (CSAE) and for any child sexual '
            'abuse material (CSAM).',
          ),
          _heading('What is prohibited'),
          _bullet('Sexualizing, exploiting, endangering or abusing a child.'),
          _bullet('Any child sexual abuse material (CSAM), or seeking it.'),
          _bullet('Grooming, soliciting or engaging a minor.'),
          _bullet('Impersonating a minor, or misrepresenting age to use the app.'),
          _heading('How to report'),
          _bullet('Use the form above — it reaches us directly.'),
          _bullet('Or use Report on any profile or in any chat.'),
          _bullet('Or email niaz@k53tech.com at any time.'),
          _heading('What we do about it'),
          _bullet('We review reports promptly and remove violating content and accounts.'),
          _bullet('We permanently ban offenders and preserve relevant evidence.'),
          _bullet(
            'Where CSAM is identified we report it to the National Center for '
            'Missing & Exploited Children (NCMEC) and to the relevant authorities, '
            'in line with applicable law.',
          ),
          _heading('Point of contact'),
          _para(
            'Our designated child-safety point of contact is reachable at '
            'niaz@k53tech.com and can speak to our CSAE and CSAM prevention '
            'practices and compliance.',
          ),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          text,
          style: AppTextStyles.textBaseBold.copyWith(color: AppColors.gray700),
        ),
      );

  Widget _para(String text) => Text(
        text,
        style: AppTextStyles.textSm
            .copyWith(color: AppColors.gray600, height: 1.55),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.gray400,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(child: _para(text)),
          ],
        ),
      );
}
