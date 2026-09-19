import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

/// Someone's live availability, as last announced by the server.
class UserPresence {
  const UserPresence({required this.isOnline, required this.isInCall});

  final bool isOnline;
  final bool isInCall;

  @override
  bool operator ==(Object other) =>
      other is UserPresence &&
      other.isOnline == isOnline &&
      other.isInCall == isInCall;

  @override
  int get hashCode => Object.hash(isOnline, isInCall);
}

/// Live "online / on a call" state, keyed by user id.
///
/// The server announces every change over `user:status_change`, but until this
/// existed the only thing done with it was to refetch the conversations list —
/// so everywhere else, most visibly the Home grid, kept showing someone as
/// busy on a call long after they had hung up, until the list happened to be
/// fetched again.
///
/// Held separately rather than written back into the fetched lists because
/// those come from a FutureProvider whose cache cannot be edited in place, and
/// refetching every list on every announcement would be a storm: the server
/// broadcasts to everyone, on every change.
class PresenceNotifier extends Notifier<Map<String, UserPresence>> {
  @override
  Map<String, UserPresence> build() => const {};

  void apply(String userId, {required bool isOnline, required bool isInCall}) {
    if (userId.isEmpty) return;
    final next = UserPresence(isOnline: isOnline, isInCall: isInCall);
    if (state[userId] == next) return;
    state = {...state, userId: next};
  }

  /// Dropped on logout so one account's view never bleeds into the next.
  void clear() => state = const {};
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, Map<String, UserPresence>>(
  PresenceNotifier.new,
);

/// A user with any live presence update laid over the fetched values.
User withPresence(User u, Map<String, UserPresence> presence) {
  final p = presence[u.id.toString()];
  if (p == null) return u;
  if (u.isOnline == p.isOnline && u.isInCall == p.isInCall) return u;
  return u.copyWith(isOnline: p.isOnline, isInCall: p.isInCall);
}

/// Same, for a list. Returns the original instance when nothing changed, so
/// Riverpod's `==` comparison can suppress a pointless rebuild.
List<User> withPresenceAll(List<User> users, Map<String, UserPresence> presence) {
  if (presence.isEmpty) return users;
  var changed = false;
  final out = <User>[];
  for (final u in users) {
    final v = withPresence(u, presence);
    if (!identical(v, u)) changed = true;
    out.add(v);
  }
  return changed ? out : users;
}
