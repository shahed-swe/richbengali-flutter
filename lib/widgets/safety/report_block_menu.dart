import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/users_repository.dart';
import '../../state/users_provider.dart';

/// Report + Block actions for a user. Required for Google Play's UGC + Child
/// Safety policies (dating/social apps must let users report and block).
///
/// Exposed as [ReportBlockMenu] (a standalone ⋮ button) and as top-level
/// [showReportSheet] / [confirmBlock] so screens with an existing menu can add
/// the items without a second icon.

const _kRose = Color(0xFFF43F5E);

/// Opens the report bottom sheet and submits the report.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  String? userName,
}) async {
  final result = await showModalBottomSheet<_ReportResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(userName: userName),
  );
  if (result == null) return;
  try {
    await ref
        .read(usersRepositoryProvider)
        .reportUser(userId, reason: result.reason, details: result.details);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your report has been submitted.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit the report. Please try again.')),
      );
    }
  }
}

/// Confirms and blocks the user. Calls [onBlocked] on success.
Future<void> confirmBlock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  String? userName,
  VoidCallback? onBlocked,
}) async {
  final name = userName?.trim().isNotEmpty == true ? userName!.trim() : 'this user';
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Block $name?'),
      content: const Text(
        'They will no longer see your profile or be able to message or call you, '
        "and you won't see them either. You can unblock later.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kRose),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(usersRepositoryProvider).blockUser(userId);
    try {
      ref.invalidate(usersProvider); // drop them from discovery
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name has been blocked.')),
      );
    }
    onBlocked?.call();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not block. Please try again.')),
      );
    }
  }
}

class ReportBlockMenu extends ConsumerWidget {
  const ReportBlockMenu({
    super.key,
    required this.userId,
    this.userName,
    this.onBlocked,
    this.iconColor,
  });

  final String userId;
  final String? userName;
  final VoidCallback? onBlocked;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (value) {
        if (value == 'report') {
          showReportSheet(context, ref, userId: userId, userName: userName);
        } else if (value == 'block') {
          confirmBlock(context, ref, userId: userId, userName: userName, onBlocked: onBlocked);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Report'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: ListTile(
            leading: Icon(Icons.block, color: _kRose),
            title: Text('Block'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _ReportResult {
  const _ReportResult(this.reason, this.details);
  final String reason;
  final String? details;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({this.userName});
  final String? userName;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = <MapEntry<String, String>>[
    MapEntry('child_safety', 'Child safety concern'),
    MapEntry('harassment', 'Harassment or abuse'),
    MapEntry('nudity_sexual', 'Nudity or sexual content'),
    MapEntry('spam_scam', 'Spam or scam'),
    MapEntry('fake_profile', 'Fake profile'),
    MapEntry('other', 'Something else'),
  ];

  String? _selected;
  final _detailsCtrl = TextEditingController();

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final name = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim()
        : 'this user';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Why are you reporting $name?',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          ..._reasons.map((e) => RadioListTile<String>(
                value: e.key,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
                title: Text(e.value),
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: _kRose,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: _detailsCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Add details (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kRose),
              onPressed: _selected == null
                  ? null
                  : () => Navigator.pop(
                        context,
                        _ReportResult(_selected!, _detailsCtrl.text),
                      ),
              child: const Text('Submit report'),
            ),
          ),
        ],
      ),
    );
  }
}
