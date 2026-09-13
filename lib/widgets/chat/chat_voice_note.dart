import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/message.dart';

String _clock(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// A voice note in the thread: play/pause, a scrubbable progress bar and the
/// elapsed/total time. The player is created lazily on first play so a thread
/// full of voice notes does not open a decoder for every one of them.
class ChatVoiceNote extends StatefulWidget {
  const ChatVoiceNote({super.key, required this.message, required this.isOwn});

  final Message message;
  final bool isOwn;

  @override
  State<ChatVoiceNote> createState() => _ChatVoiceNoteState();
}

class _ChatVoiceNoteState extends State<ChatVoiceNote> {
  AudioPlayer? _player;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    _player = player;

    player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    player.playerStateStream.listen((s) {
      if (!mounted) return;
      if (s.processingState == ProcessingState.completed) {
        // Leave it ready to play again from the top.
        player.pause();
        player.seek(Duration.zero);
        setState(() => _playing = false);
      } else {
        setState(() => _playing = s.playing);
      }
    });

    final url = widget.message.attachmentUrl!;
    if (widget.message.isLocalAttachment) {
      await player.setFilePath(url);
    } else {
      await player.setUrl(url);
    }
    return player;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final player = await _ensurePlayer();
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't play that voice message.")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = widget.isOwn;
    final fg = isOwn ? Colors.white : const Color(0xFF0F172A);
    final track = isOwn
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFFCBD5E1);
    final fill = isOwn ? Colors.white : const Color(0xFFF43F5E);

    // Fall back to the recorded length only once known; until then show the
    // elapsed time so the row never sits at a misleading 0:00 total.
    final total = _duration == Duration.zero ? null : _duration;
    final label = total == null
        ? _clock(_position)
        : '${_clock(_position)} / ${_clock(total)}';

    final progress = (total == null || total.inMilliseconds == 0)
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    final uploading = widget.message.isLocalAttachment &&
        !File(widget.message.attachmentUrl!).existsSync();

    return SizedBox(
      width: 210,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: uploading ? null : _toggle,
            child: SizedBox(
              width: 34,
              height: 34,
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      ),
                    )
                  : Icon(
                      _playing
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      size: 34,
                      color: fg,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: fill,
                    inactiveTrackColor: track,
                    thumbColor: fill,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: total == null
                        ? null
                        : (v) {
                            final target = Duration(
                              milliseconds:
                                  (total.inMilliseconds * v).round(),
                            );
                            setState(() => _position = target);
                            _player?.seek(target);
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isOwn
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
