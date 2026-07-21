import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/messages_repository.dart';
import '../models/message.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MessagesState {
  final List<Message> messages;
  final bool isLoading;

  /// True once history has been fetched successfully at least once. Distinct
  /// from "messages is empty" (a real, loaded, empty chat). Used to retry a
  /// failed load when the chat is reopened instead of showing empty forever.
  final bool loaded;

  /// IDs of messages we know have been deleted — used for DEDUP
  final Set<String> deletedIds;

  /// Whether older history pages may still exist on the server (Messenger-style
  /// scroll-up pagination). Starts true; set false once a page comes back short.
  final bool hasMore;

  /// An older-page fetch is in flight (guards double-triggers from scrolling).
  final bool loadingOlder;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.loaded = false,
    this.deletedIds = const {},
    this.hasMore = true,
    this.loadingOlder = false,
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? loaded,
    Set<String>? deletedIds,
    bool? hasMore,
    bool? loadingOlder,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      loaded: loaded ?? this.loaded,
      deletedIds: deletedIds ?? this.deletedIds,
      hasMore: hasMore ?? this.hasMore,
      loadingOlder: loadingOlder ?? this.loadingOlder,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier — constructor-field pattern (Riverpod 3)
// ---------------------------------------------------------------------------

class MessagesNotifier extends Notifier<MessagesState> {
  MessagesNotifier(this.otherUserId);
  final String otherUserId;

  /// Initial page: enough to fill the screen with the LATEST messages.
  static const int _initialPageSize = 30;

  /// Older-history pages loaded when the user scrolls up (Messenger-style).
  static const int _olderPageSize = 15;

  @override
  MessagesState build() {
    // Kick off async load; state starts empty
    _load();
    return const MessagesState(isLoading: true);
  }

  // NOTE: must not touch `state` before the first `await` — build() calls this
  // synchronously before the initial state is assigned.
  Future<void> _load() async {
    // Retry a couple of times — a single transient failure must NOT strand the
    // (kept-alive) provider in a permanent empty state (BUG #5a).
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final msgs = await ref
            .read(messagesRepositoryProvider)
            .getMessages(otherUserId, limit: _initialPageSize);
        final sorted = List<Message>.from(msgs)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = state.copyWith(
          messages: sorted,
          isLoading: false,
          loaded: true,
          // A full first page means older history may exist above it.
          hasMore: msgs.length >= _initialPageSize,
        );
        return;
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    // All attempts failed — leave loaded=false so reopening the chat retries.
    state = state.copyWith(isLoading: false);
  }

  /// Called when the chat screen (re)opens. Because the provider is kept alive
  /// for the whole session, a chat that failed to load once would otherwise show
  /// "No messages yet" forever; this re-fetches when it wasn't loaded (or was
  /// cleared) so reopening always recovers (BUG #5a / #5b).
  void ensureLoaded() {
    if (!state.loaded && !state.isLoading) {
      state = state.copyWith(isLoading: true);
      _load();
    }
  }

  /// Called on every chat open. Guarantees the thread is CURRENT:
  /// • never loaded / previously cleared → full initial load (with spinner)
  /// • already loaded → silent latest-page re-fetch merged in, so messages that
  ///   arrived while the user was elsewhere (home page, other chat) appear
  ///   without an app restart and without a loading flash.
  void syncOnOpen() {
    if (!state.loaded) {
      ensureLoaded();
    } else {
      refresh();
    }
  }

  /// Re-fetch the LATEST page and merge. Silent when content is already loaded
  /// (no isLoading flip → no full-screen spinner flash on an open chat).
  Future<void> refresh() async {
    final prev = state;
    if (!prev.loaded) state = prev.copyWith(isLoading: true);
    try {
      final msgs = await ref
          .read(messagesRepositoryProvider)
          .getMessages(otherUserId, limit: _initialPageSize);
      state = _merge(state, msgs);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Load the previous (older) history page — triggered when the user scrolls
  /// near the top. Returns true if anything new was added (screen uses it to
  /// keep the scroll position anchored).
  Future<bool> loadOlder() async {
    final s = state;
    if (!s.loaded || s.loadingOlder || !s.hasMore || s.messages.isEmpty) {
      return false;
    }
    state = s.copyWith(loadingOlder: true);
    try {
      final oldest = state.messages.first;
      final page = await ref.read(messagesRepositoryProvider).getMessages(
            otherUserId,
            limit: _olderPageSize,
            before: oldest.createdAt,
          );
      final grewBy = page
          .where((m) => !state.messages.any((e) => e.id == m.id))
          .length;
      state = _merge(state, page).copyWith(
        // A short page means we've reached the beginning of the thread.
        hasMore: page.length >= _olderPageSize,
        loadingOlder: false,
      );
      return grewBy > 0;
    } catch (_) {
      state = state.copyWith(loadingOlder: false);
      return false;
    }
  }

  MessagesState _merge(MessagesState prev, List<Message> apiMsgs) {
    final map = <String, Message>{};
    for (final m in apiMsgs) {
      if (!prev.deletedIds.contains(m.id)) map[m.id] = m;
    }
    for (final m in prev.messages) {
      if (!map.containsKey(m.id) && !prev.deletedIds.contains(m.id)) {
        map[m.id] = m;
      }
    }
    final sorted = map.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return MessagesState(
        messages: sorted,
        deletedIds: prev.deletedIds,
        isLoading: false,
        loaded: true,
        hasMore: prev.hasMore,
        loadingOlder: prev.loadingOlder);
  }

  /// Append a realtime message from socket `chat:message` with DEDUP.
  void appendRealtime(Message msg) {
    final s = state;
    if (s.deletedIds.contains(msg.id)) return;
    if (s.messages.any((m) => m.id == msg.id)) return;
    final updated = List<Message>.from(s.messages)..add(msg);
    updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = s.copyWith(messages: updated);
  }

  /// Optimistic send: append immediately then reconcile from API.
  Future<void> sendMessage(String myId, String content) async {
    final optimisticId =
        'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Message(
      id: optimisticId,
      senderId: myId,
      receiverId: otherUserId,
      content: content,
      createdAt: DateTime.now().toIso8601String(),
    );

    final prev = state;
    state = prev.copyWith(
      messages: List<Message>.from(prev.messages)..add(optimistic),
    );

    try {
      final saved = await ref
          .read(messagesRepositoryProvider)
          .sendMessage(otherUserId, content);
      final s = state;
      final updated =
          s.messages.where((m) => m.id != optimisticId).toList();
      if (!updated.any((m) => m.id == saved.id)) updated.add(saved);
      updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = s.copyWith(messages: updated);
    } catch (e) {
      final s = state;
      state = s.copyWith(
        messages: s.messages.where((m) => m.id != optimisticId).toList(),
      );
      rethrow;
    }
  }

  /// Mark all messages as seen — called when the peer opens/views the chat
  /// (server `chat:seen`). Only own-message bubbles display the read tick, so
  /// marking the whole list is harmless and keeps it simple.
  void markAllSeen() {
    final s = state;
    if (s.messages.every((m) => m.seen)) return;
    state = s.copyWith(
      messages: [
        for (final m in s.messages) m.seen ? m : m.copyWith(seen: true),
      ],
    );
  }

  /// Remove a message by id.
  void removeMessage(String messageId) {
    final s = state;
    final updatedDeleted = Set<String>.from(s.deletedIds)..add(messageId);
    state = s.copyWith(
      messages: s.messages.where((m) => m.id != messageId).toList(),
      deletedIds: updatedDeleted,
    );
  }

  /// Clear all messages.
  void clearAll() {
    state = const MessagesState();
  }
}

// ---------------------------------------------------------------------------
// Provider — family using constructor-field pattern
// ---------------------------------------------------------------------------

final messagesProvider =
    NotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (arg) => MessagesNotifier(arg),
);
