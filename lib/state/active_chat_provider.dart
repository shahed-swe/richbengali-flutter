import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// currentChatPeerIdProvider — the otherUserId of the chat currently VISIBLE
// on screen, or null when no chat is visible (Home/Favorites/Plans/Me, the
// Chats list, or a different chat is on top).
//
// This is the client-authoritative source of truth for "am I looking at this
// chat right now?" — used to decide whether an incoming chat:message should
// surface a visible notification banner (see SocketService.chat:message
// handler) and kept in sync with the backend's own activeByUser tracking via
// chat:active / chat:inactive emits.
// ---------------------------------------------------------------------------

class CurrentChatPeerIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? peerId) {
    state = peerId;
  }

  void clear() {
    state = null;
  }
}

final currentChatPeerIdProvider =
    NotifierProvider<CurrentChatPeerIdNotifier, String?>(
  CurrentChatPeerIdNotifier.new,
);
