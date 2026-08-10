import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'refresh_in_place.dart';
import '../data/messages_repository.dart';
import '../models/conversation.dart';

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    return ref.read(messagesRepositoryProvider).getConversations();
  }

  /// Refetch without tearing the current data off the screen.
  Future<void> refresh() async {
    state = await refreshedState(
      state,
      () => ref.read(messagesRepositoryProvider).getConversations(),
    );
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
