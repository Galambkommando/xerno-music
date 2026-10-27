import 'dart:math';

enum RepeatMode { off, all, one }

RepeatMode repeatModeFromName(String? raw) {
  return switch (raw) {
    'all' => RepeatMode.all,
    'one' => RepeatMode.one,
    _ => RepeatMode.off,
  };
}

class QueueStep {
  const QueueStep.play(this.id) : restart = false, stopped = false;
  const QueueStep.restart() : id = null, restart = true, stopped = false;
  const QueueStep.stop() : id = null, restart = false, stopped = true;

  final String? id;
  final bool restart;
  final bool stopped;
}

class PlayQueue {
  PlayQueue({Random? random}) : _random = random ?? Random();

  final Random _random;
  List<String> _linear = [];
  List<String> _order = [];
  int index = 0;
  bool shuffle = false;
  RepeatMode repeat = RepeatMode.off;

  List<String> get order => List.unmodifiable(_order);
  List<String> get linear => List.unmodifiable(_linear);

  String? get currentId {
    if (_order.isEmpty || index < 0 || index >= _order.length) return null;
    return _order[index];
  }

  void replace(List<String> ids, int start) {
    _linear = List<String>.of(ids);
    _order = List<String>.of(ids);
    if (ids.isEmpty) {
      index = 0;
      return;
    }
    index = start.clamp(0, ids.length - 1);
    if (shuffle) _shuffleTail();
  }

  void setShuffle(bool enabled) {
    if (enabled == shuffle) return;
    final current = currentId;
    shuffle = enabled;
    if (!enabled) {
      _order = List<String>.of(_linear);
      if (current != null) {
        final found = _order.indexOf(current);
        index = found < 0 ? 0 : found;
      } else {
        index = 0;
      }
      return;
    }
    _order = List<String>.of(_linear);
    if (current != null) {
      final found = _order.indexOf(current);
      index = found < 0 ? 0 : found;
    }
    _shuffleTail();
  }

  void setRepeat(RepeatMode mode) {
    repeat = mode;
  }

  void cycleRepeat() {
    repeat = switch (repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
  }

  String? peekUpcomingId() {
    if (_order.isEmpty || repeat == RepeatMode.one) return null;
    if (index + 1 < _order.length) return _order[index + 1];
    if (repeat == RepeatMode.all) return _order.first;
    return null;
  }

  QueueStep complete() {
    if (_order.isEmpty) return const QueueStep.stop();
    if (repeat == RepeatMode.one) return const QueueStep.restart();
    if (index + 1 < _order.length) {
      index += 1;
      return QueueStep.play(_order[index]);
    }
    if (repeat == RepeatMode.all) {
      index = 0;
      return QueueStep.play(_order[index]);
    }
    return const QueueStep.stop();
  }

  QueueStep skipNext() {
    if (_order.isEmpty) return const QueueStep.stop();
    if (index + 1 < _order.length) {
      index += 1;
      return QueueStep.play(_order[index]);
    }
    if (repeat != RepeatMode.off) {
      index = 0;
      return QueueStep.play(_order[index]);
    }
    return const QueueStep.stop();
  }

  QueueStep skipPrevious(Duration position) {
    if (_order.isEmpty) return const QueueStep.stop();
    if (position > const Duration(seconds: 3)) {
      return const QueueStep.restart();
    }
    if (index > 0) {
      index -= 1;
      return QueueStep.play(_order[index]);
    }
    if (repeat == RepeatMode.all) {
      index = _order.length - 1;
      return QueueStep.play(_order[index]);
    }
    return const QueueStep.restart();
  }

  void moveTo(String id) {
    if (currentId == id) return;
    final next = index + 1;
    if (next < _order.length && _order[next] == id) {
      index = next;
      return;
    }
    if (repeat == RepeatMode.all && _order.isNotEmpty && _order.first == id) {
      index = 0;
      return;
    }
    final found = _order.indexOf(id);
    if (found >= 0) index = found;
  }

  void addNext(String id) {
    final at = _order.isEmpty ? 0 : index + 1;
    _order.insert(at.clamp(0, _order.length), id);
    final current = currentId;
    if (current == null) {
      _linear.add(id);
      return;
    }
    final linearIndex = _linear.indexOf(current);
    if (linearIndex < 0) {
      _linear.add(id);
    } else {
      _linear.insert(linearIndex + 1, id);
    }
  }

  void addLast(String id) {
    _order.add(id);
    _linear.add(id);
  }

  void removeAt(int i) {
    if (i < 0 || i >= _order.length) return;
    final id = _order.removeAt(i);
    final remaining = _order.where((item) => item == id).length;
    final linearRemaining = _linear.where((item) => item == id).length;
    if (linearRemaining > remaining) {
      final linearIndex = _linear.indexOf(id);
      if (linearIndex >= 0) _linear.removeAt(linearIndex);
    }
    if (_order.isEmpty) {
      index = 0;
      return;
    }
    if (i < index) index -= 1;
    if (index >= _order.length) index = _order.length - 1;
  }

  void move(int from, int to) {
    if (from < 0 ||
        to < 0 ||
        from >= _order.length ||
        to >= _order.length ||
        from == to) {
      return;
    }
    final id = _order.removeAt(from);
    _order.insert(to, id);
    if (index == from) {
      index = to;
    } else if (from < index && to >= index) {
      index -= 1;
    } else if (from > index && to <= index) {
      index += 1;
    }
  }

  void clearAfterCurrent() {
    if (_order.isEmpty) return;
    _order = _order.take(index + 1).toList();
    final keep = _order.toSet();
    _linear = [
      for (final id in _linear)
        if (keep.contains(id)) id,
    ];
  }

  void _shuffleTail() {
    if (index >= _order.length - 1) return;
    final tail = _order.sublist(index + 1);
    for (var i = tail.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final swap = tail[i];
      tail[i] = tail[j];
      tail[j] = swap;
    }
    _order = [..._order.take(index + 1), ...tail];
  }
}
