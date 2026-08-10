import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/messages_repository.dart';
import '../models/conversation.dart';

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    return ref.read(messagesRepositoryProvider).getConversations();
  }

  /// Refetch without discarding the current data.
  ///
  /// `invalidateSelf` re-runs `build()` while Riverpod keeps the previous
  /// value attached to the new `AsyncLoading`. Because `AsyncValue.when`
  /// defaults to `skipLoadingOnRefresh: true`, the UI keeps rendering the old
  /// list and swaps in the new one when it arrives, instead of flashing a
  /// full-screen spinner on every pull-to-refresh or socket-driven refresh.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The error is already surfaced through `state` as AsyncError; swallow it
      // here so callers like RefreshIndicator.onRefresh never see an unhandled
      // rejection.
    }
  }

  /// Update online/in-call status for a specific user from socket event.
  void updateUserStatus(String userId, bool isOnline, bool isInCall) {
    state = state.whenData((convos) {
      return convos.map((c) {
        if (c.otherUser.id == userId) {
          return c.copyWith(
            otherUser: c.otherUser.copyWith(
              isOnline: isOnline,
              isInCall: isInCall,
            ),
          );
        }
        return c;
      }).toList();
    });
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);
