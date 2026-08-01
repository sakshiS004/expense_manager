import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:expense_manager/sync/sync_queue.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final syncQueue = context.read<SyncQueue>();

    return AnimatedBuilder(
      animation: Listenable.merge([
        syncQueue.isOnline,
        syncQueue.syncStatus,
        syncQueue.pendingChangeCount,
      ]),
      builder: (context, _) {
        final online = syncQueue.isOnline.value;
        final pending = syncQueue.pendingChangeCount.value;

        if (!online) {
          return _StatusPill(
            color: Colors.amber.shade700,
            child: Text('Offline • $pending change${pending == 1 ? '' : 's'} pending'),
          );
        }

        switch (syncQueue.syncStatus.value) {
          case SyncQueueStatus.syncing:
            return const _StatusPill(
              color: Colors.blue,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SpinningGlyph(child: Text('↻')),
                  SizedBox(width: 4),
                  Text('Syncing...'),
                ],
              ),
            );
          case SyncQueueStatus.error:
            return _StatusPill(
              color: Colors.red.shade700,
              child: const Text('Sync error'),
            );
          case SyncQueueStatus.offline:
          case SyncQueueStatus.synced:
            return _StatusPill(
              color: Colors.green.shade700,
              child: const Text('✓ Synced'),
            );
        }
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        child: child,
      ),
    );
  }
}

class _SpinningGlyph extends StatefulWidget {
  const _SpinningGlyph({required this.child});

  final Widget child;

  @override
  State<_SpinningGlyph> createState() => _SpinningGlyphState();
}

class _SpinningGlyphState extends State<_SpinningGlyph> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}