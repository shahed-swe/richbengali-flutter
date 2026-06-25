import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/messages_repository.dart';
import '../models/message.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class MessagesState {
  final List<Message> messages;
  final bool isLoading;

  /// IDs of messages we know have been deleted — used for DEDUP
  final Set<String> deletedIds;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.deletedIds = const {},
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    Set<String>? deletedIds,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      deletedIds: deletedIds ?? this.deletedIds,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier — constructor-field pattern (Riverpod 3)
// ---------------------------------------------------------------------------

class MessagesNotifier extends Notifier<MessagesState> {
  MessagesNotifier(this.otherUserId);
  final String otherUserId;

  @override
  MessagesState build() {
    // Kick off async load; state starts empty
    _load();
    return const MessagesState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      final msgs =
          await ref.read(messagesRepositoryProvider).getMessages(otherUserId);
      final sorted = List<Message>.from(msgs)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = state.copyWith(messages: sorted, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    final prev = state;
    state = prev.copyWith(isLoading: true);
    try {
      final msgs = await ref
          .read(messagesRepositoryProvider)
          .getMessages(otherUserId);
      state = _merge(prev, msgs);
    } catch (_) {
      state = state.copyWith(isLoading: false);
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
        messages: sorted, deletedIds: prev.deletedIds, isLoading: false);
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
