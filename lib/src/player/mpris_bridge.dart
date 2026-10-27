import 'dart:async';
import 'dart:developer';

import 'package:dbus/dbus.dart';

import '../constants.dart';
import '../logic/play_queue.dart';
import '../platform_info.dart';
import 'desktop_window.dart';
import 'playback.dart';
import 'xerno_engine.dart';

class MprisBridge {
  MprisBridge(this.engine);

  final XernoEngine engine;
  DBusClient? _client;
  _MprisObject? _object;
  StreamSubscription<PlayerSnapshot>? _subscription;

  Future<void> start() async {
    if (!isLinuxDesktop) return;
    try {
      final client = DBusClient.session();
      final reply = await client.requestName(
        'org.mpris.MediaPlayer2.xernomusic',
        flags: {DBusRequestNameFlag.doNotQueue},
      );
      if (reply != DBusRequestNameReply.primaryOwner &&
          reply != DBusRequestNameReply.alreadyOwner) {
        log('MPRIS name was not acquired ($reply).');
        await client.close();
        return;
      }
      final object = _MprisObject(engine);
      await client.registerObject(object);
      _client = client;
      _object = object;
      _subscription = engine.snapshots.listen(object.note);
      object.note(engine.snapshot);
    } catch (error, stack) {
      log('MPRIS is unavailable.', error: error, stackTrace: stack);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    final client = _client;
    final object = _object;
    _client = null;
    _object = null;
    if (client == null) return;
    if (object != null) {
      try {
        await client.unregisterObject(object);
      } catch (error, stack) {
        log(
          'MPRIS object could not be unregistered.',
          error: error,
          stackTrace: stack,
        );
      }
    }
    await client.close();
  }
}

class _MprisObject extends DBusObject {
  _MprisObject(this.engine) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  final XernoEngine engine;
  String _status = 'Stopped';
  double _volume = 0.9;
  bool _shuffle = false;
  String _loop = 'None';
  double _rate = 1;
  DBusDict _metadata = DBusDict.stringVariant(const {});

  static const _root = 'org.mpris.MediaPlayer2';
  static const _player = 'org.mpris.MediaPlayer2.Player';

  void note(PlayerSnapshot snapshot) {
    final status = !snapshot.hasTrack
        ? 'Stopped'
        : snapshot.playing
        ? 'Playing'
        : 'Paused';
    final metadata = _metadataFor(snapshot);
    final loop = switch (snapshot.repeat) {
      RepeatMode.off => 'None',
      RepeatMode.all => 'Playlist',
      RepeatMode.one => 'Track',
    };
    final changed = <String, DBusValue>{};
    if (status != _status) {
      _status = status;
      changed['PlaybackStatus'] = DBusString(status);
    }
    if (snapshot.volume != _volume) {
      _volume = snapshot.volume;
      changed['Volume'] = DBusDouble(snapshot.volume);
    }
    if (snapshot.shuffle != _shuffle) {
      _shuffle = snapshot.shuffle;
      changed['Shuffle'] = DBusBoolean(snapshot.shuffle);
    }
    if (loop != _loop) {
      _loop = loop;
      changed['LoopStatus'] = DBusString(loop);
    }
    if (snapshot.speed != _rate) {
      _rate = snapshot.speed;
      changed['Rate'] = DBusDouble(snapshot.speed);
    }
    if (metadata.toString() != _metadata.toString()) {
      _metadata = metadata;
      changed['Metadata'] = metadata;
    }
    if (changed.isEmpty || client == null) return;
    unawaited(emitPropertiesChanged(_player, changedProperties: changed));
  }

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        _root,
        methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
        properties: [
          DBusIntrospectProperty(
            'CanQuit',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanRaise',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'Identity',
            DBusSignature('s'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'DesktopEntry',
            DBusSignature('s'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'SupportedUriSchemes',
            DBusSignature('as'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'SupportedMimeTypes',
            DBusSignature('as'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'HasTrackList',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
        ],
      ),
      DBusIntrospectInterface(
        _player,
        methods: [
          DBusIntrospectMethod('Next'),
          DBusIntrospectMethod('Previous'),
          DBusIntrospectMethod('Pause'),
          DBusIntrospectMethod('PlayPause'),
          DBusIntrospectMethod('Stop'),
          DBusIntrospectMethod('Play'),
          DBusIntrospectMethod(
            'Seek',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.in_,
                name: 'Offset',
              ),
            ],
          ),
          DBusIntrospectMethod(
            'SetPosition',
            args: [
              DBusIntrospectArgument(
                DBusSignature('o'),
                DBusArgumentDirection.in_,
                name: 'TrackId',
              ),
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.in_,
                name: 'Position',
              ),
            ],
          ),
        ],
        properties: [
          DBusIntrospectProperty(
            'PlaybackStatus',
            DBusSignature('s'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty('LoopStatus', DBusSignature('s')),
          DBusIntrospectProperty('Rate', DBusSignature('d')),
          DBusIntrospectProperty('Shuffle', DBusSignature('b')),
          DBusIntrospectProperty(
            'Metadata',
            DBusSignature('a{sv}'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty('Volume', DBusSignature('d')),
          DBusIntrospectProperty(
            'Position',
            DBusSignature('x'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'MinimumRate',
            DBusSignature('d'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'MaximumRate',
            DBusSignature('d'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanGoNext',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanGoPrevious',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanPlay',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanPause',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanSeek',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
          DBusIntrospectProperty(
            'CanControl',
            DBusSignature('b'),
            access: DBusPropertyAccess.read,
          ),
        ],
        signals: [
          DBusIntrospectSignal(
            'Seeked',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.out,
                name: 'Position',
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    switch (methodCall.name) {
      case 'Raise':
        await DesktopWindow.present();
        return DBusMethodSuccessResponse();
      case 'Quit':
        return DBusMethodSuccessResponse();
      case 'Next':
        await engine.next();
        return DBusMethodSuccessResponse();
      case 'Previous':
        await engine.previous();
        return DBusMethodSuccessResponse();
      case 'Pause':
        await engine.pause();
        return DBusMethodSuccessResponse();
      case 'Play':
        await engine.play();
        return DBusMethodSuccessResponse();
      case 'PlayPause':
        await engine.toggle();
        return DBusMethodSuccessResponse();
      case 'Stop':
        await engine.stop();
        return DBusMethodSuccessResponse();
      case 'Seek':
        final offset = methodCall.values.isEmpty
            ? 0
            : methodCall.values.first.asInt64();
        final next = engine.snapshot.position + Duration(microseconds: offset);
        await engine.seek(next < Duration.zero ? Duration.zero : next);
        await emitSignal(_player, 'Seeked', [DBusInt64(next.inMicroseconds)]);
        return DBusMethodSuccessResponse();
      case 'SetPosition':
        if (methodCall.values.length < 2) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        final position = methodCall.values[1].asInt64();
        await engine.seek(Duration(microseconds: position));
        await emitSignal(_player, 'Seeked', [DBusInt64(position)]);
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == _root) {
      return switch (name) {
        'CanQuit' => DBusGetPropertyResponse(const DBusBoolean(false)),
        'CanRaise' => DBusGetPropertyResponse(const DBusBoolean(true)),
        'HasTrackList' => DBusGetPropertyResponse(const DBusBoolean(false)),
        'Identity' => DBusGetPropertyResponse(DBusString(kAppName)),
        'DesktopEntry' => DBusGetPropertyResponse(DBusString(kDesktopEntry)),
        'SupportedUriSchemes' => DBusGetPropertyResponse(
          _stringArray(['file', 'http', 'https']),
        ),
        'SupportedMimeTypes' => DBusGetPropertyResponse(
          _stringArray(['audio/mpeg']),
        ),
        _ => DBusMethodErrorResponse.unknownProperty(),
      };
    }
    if (interface == _player) {
      return switch (name) {
        'PlaybackStatus' => DBusGetPropertyResponse(DBusString(_status)),
        'LoopStatus' => DBusGetPropertyResponse(DBusString(_loop)),
        'Rate' => DBusGetPropertyResponse(DBusDouble(_rate)),
        'MinimumRate' => DBusGetPropertyResponse(const DBusDouble(0.5)),
        'MaximumRate' => DBusGetPropertyResponse(const DBusDouble(2)),
        'Shuffle' => DBusGetPropertyResponse(DBusBoolean(_shuffle)),
        'Metadata' => DBusGetPropertyResponse(_metadata),
        'Volume' => DBusGetPropertyResponse(DBusDouble(_volume)),
        'Position' => DBusGetPropertyResponse(
          DBusInt64(engine.snapshot.position.inMicroseconds),
        ),
        'CanGoNext' ||
        'CanGoPrevious' ||
        'CanPlay' ||
        'CanPause' ||
        'CanSeek' ||
        'CanControl' => DBusGetPropertyResponse(const DBusBoolean(true)),
        _ => DBusMethodErrorResponse.unknownProperty(),
      };
    }
    return DBusMethodErrorResponse.unknownInterface();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (interface == _root) {
      return DBusGetAllPropertiesResponse({
        'CanQuit': const DBusBoolean(false),
        'CanRaise': const DBusBoolean(true),
        'HasTrackList': const DBusBoolean(false),
        'Identity': DBusString(kAppName),
        'DesktopEntry': DBusString(kDesktopEntry),
        'SupportedUriSchemes': _stringArray(['file', 'http', 'https']),
        'SupportedMimeTypes': _stringArray(['audio/mpeg']),
      });
    }
    if (interface == _player) {
      return DBusGetAllPropertiesResponse({
        'PlaybackStatus': DBusString(_status),
        'LoopStatus': DBusString(_loop),
        'Rate': DBusDouble(_rate),
        'MinimumRate': const DBusDouble(0.5),
        'MaximumRate': const DBusDouble(2),
        'Shuffle': DBusBoolean(_shuffle),
        'Metadata': _metadata,
        'Volume': DBusDouble(_volume),
        'Position': DBusInt64(engine.snapshot.position.inMicroseconds),
        'CanGoNext': const DBusBoolean(true),
        'CanGoPrevious': const DBusBoolean(true),
        'CanPlay': const DBusBoolean(true),
        'CanPause': const DBusBoolean(true),
        'CanSeek': const DBusBoolean(true),
        'CanControl': const DBusBoolean(true),
      });
    }
    return DBusGetAllPropertiesResponse(const {});
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface != _player) return DBusMethodErrorResponse.propertyReadOnly();
    switch (name) {
      case 'Volume':
        await engine.setVolume(value.asDouble());
        return DBusMethodSuccessResponse();
      case 'Shuffle':
        await engine.setShuffle(value.asBoolean());
        return DBusMethodSuccessResponse();
      case 'Rate':
        await engine.setSpeed(value.asDouble());
        return DBusMethodSuccessResponse();
      case 'LoopStatus':
        final mode = switch (value.asString()) {
          'Playlist' => RepeatMode.all,
          'Track' => RepeatMode.one,
          _ => RepeatMode.off,
        };
        await engine.setRepeat(mode);
        return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.propertyReadOnly();
  }
}

DBusDict _metadataFor(PlayerSnapshot snapshot) {
  final track = snapshot.track;
  if (track == null) return DBusDict.stringVariant(const {});
  final safeId = track.id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  final values = <String, DBusValue>{
    'mpris:trackid': DBusObjectPath('/online/mucsarocsoge/xerno/track/$safeId'),
    'mpris:length': DBusInt64(
      (snapshot.duration == Duration.zero ? track.duration : snapshot.duration)
          .inMicroseconds,
    ),
    'xesam:title': DBusString(track.title),
    'xesam:album': DBusString(track.album),
    'xesam:artist': DBusArray(DBusSignature('s'), [DBusString(track.artist)]),
  };
  final art = track.artUri;
  if (art != null) values['mpris:artUrl'] = DBusString(art.toString());
  return DBusDict.stringVariant(values);
}

DBusArray _stringArray(List<String> values) {
  return DBusArray(DBusSignature('s'), [
    for (final value in values) DBusString(value),
  ]);
}
