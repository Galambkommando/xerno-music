import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../format.dart';
import '../models/settings.dart';
import '../platform_info.dart';
import '../services/supabase_gate.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'playback_actions.dart';
import 'playlist_io.dart';
import 'sound_controls.dart';
import 'sync_actions.dart';
import 'widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _manifest;
  late final TextEditingController _local;
  late final TextEditingController _cloud;
  late final TextEditingController _supabaseUrl;
  late final TextEditingController _anon;
  late final TextEditingController _room;
  late final TextEditingController _rest;
  late final TextEditingController _email;
  late final TextEditingController _password;
  var _hideKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _manifest = TextEditingController(text: settings.manifestUrl);
    _local = TextEditingController(text: settings.localLibraryPath);
    _cloud = TextEditingController(text: settings.cloudBaseUrl);
    _supabaseUrl = TextEditingController(text: settings.supabaseUrl);
    _anon = TextEditingController(text: settings.supabaseAnonKey);
    _room = TextEditingController(text: settings.syncRoomCode);
    _rest = TextEditingController(text: settings.restSyncBaseUrl);
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in [
      _manifest,
      _local,
      _cloud,
      _supabaseUrl,
      _anon,
      _room,
      _rest,
      _email,
      _password,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final status = ref.watch(syncStatusProvider);
    final email = SupabaseGate.currentEmail();
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
      children: [
        const Eyebrow('PREFERENCES'),
        const SizedBox(height: 8),
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 22),
        _Panel(
          title: 'Appearance',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Frosted glass'),
                subtitle: const Text(
                  'Blur the now playing bar and modal sheets.',
                ),
                value: settings.frostedGlass,
                onChanged: (value) =>
                    _update((current) => current.copyWith(frostedGlass: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ambient glow'),
                subtitle: const Text(
                  'Blend the current cover with the forest green field.',
                ),
                value: settings.ambientGlow,
                onChanged: (value) =>
                    _update((current) => current.copyWith(ambientGlow: value)),
              ),
              if (isLinuxDesktop)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mini player'),
                  subtitle: const Text(
                    'Compact always-on-top window for the desktop.',
                  ),
                  value: settings.miniPlayer,
                  onChanged: (value) =>
                      _update((current) => current.copyWith(miniPlayer: value)),
                ),
            ],
          ),
        ),
        _Panel(
          title: 'Library',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _manifest,
                decoration: xernoField(
                  'Cloud manifest URL',
                  hint: kDefaultManifestUrl,
                ),
                onSubmitted: (_) => unawaited(_saveFields()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _refreshCloud,
                    child: const Text('Refresh manifest'),
                  ),
                  OutlinedButton(
                    onPressed: _useBundled,
                    child: const Text('Use bundled catalog'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(importCatalogFile(context, ref)),
                    child: const Text('Import JSON'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _local,
                decoration: xernoField(
                  'Local library folder',
                  hint: 'Unzipped spotify_library',
                ),
                onSubmitted: (_) => unawaited(_reloadLocal()),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _pickFolder,
                    child: const Text('Choose folder'),
                  ),
                  OutlinedButton(
                    onPressed: _reloadLocal,
                    child: const Text('Reload folder'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cloud,
                decoration: xernoField(
                  'Audio base URL',
                  hint: 'RöcsögeCloud, R2, or Supabase Storage',
                ),
                onSubmitted: (_) => unawaited(_saveFields()),
              ),
              const SizedBox(height: 14),
              const Text('Source preference'),
              const SizedBox(height: 8),
              Wrap(
                children: [
                  ChoicePill(
                    label: 'Auto',
                    selected:
                        settings.sourcePreference == SourcePreference.auto,
                    onTap: () => _prefer(SourcePreference.auto),
                  ),
                  ChoicePill(
                    label: 'Local first',
                    selected:
                        settings.sourcePreference ==
                        SourcePreference.localFirst,
                    onTap: () => _prefer(SourcePreference.localFirst),
                  ),
                  ChoicePill(
                    label: 'Cloud first',
                    selected:
                        settings.sourcePreference ==
                        SourcePreference.cloudFirst,
                    onTap: () => _prefer(SourcePreference.cloudFirst),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Auto and local first play a pin, then a file in the library folder, then a cloud URL. Cloud first tries the remote file before a pin.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Playback',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Resume on launch'),
                subtitle: const Text(
                  'Restore the last queue paused, ready to play.',
                ),
                value: settings.resumeOnLaunch,
                onChanged: (value) => _update(
                  (current) => current.copyWith(resumeOnLaunch: value),
                ),
              ),
              const SoundControls(),
            ],
          ),
        ),
        _Panel(
          title: 'Quick device sync',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share a room code between CachyOS and Android. No email is required. The code is the key to the shared playlists, favorites, and playback bookmark.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _room,
                decoration: xernoField('Sync room code'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _newRoom,
                    child: const Text('New code'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: normalizeRoomCode(_room.text)),
                      );
                      if (!context.mounted) return;
                      showNote(context, 'Copied the room code.');
                    },
                    child: const Text('Copy'),
                  ),
                  OutlinedButton(
                    onPressed: () => _push(room: true),
                    child: const Text('Push'),
                  ),
                  OutlinedButton(
                    onPressed: () => _pull(room: true),
                    child: const Text('Pull'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rest,
                decoration: xernoField(
                  'REST sync base URL',
                  hint: 'Optional, instead of Supabase',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Live sync'),
                subtitle: const Text(
                  'Listen for newer room or account updates while the app is open.',
                ),
                value: settings.liveSync,
                onChanged: (value) =>
                    _update((current) => current.copyWith(liveSync: value)),
              ),
              if (status.isNotEmpty)
                Text(status, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        _Panel(
          title: 'Supabase account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _supabaseUrl,
                decoration: xernoField('Project URL'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _anon,
                obscureText: _hideKey,
                decoration: xernoField('Anon key').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _hideKey ? 'Show key' : 'Hide key',
                    onPressed: () => setState(() => _hideKey = !_hideKey),
                    icon: Icon(
                      _hideKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _connect, child: const Text('Connect')),
              const SizedBox(height: 8),
              Text(
                email == null ? 'Signed out' : 'Signed in as $email',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: xernoField('Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: xernoField('Password'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _signIn,
                    child: const Text('Sign in'),
                  ),
                  OutlinedButton(
                    onPressed: _signUp,
                    child: const Text('Create account'),
                  ),
                  OutlinedButton(
                    onPressed: _magic,
                    child: const Text('Magic link'),
                  ),
                  OutlinedButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                  OutlinedButton(
                    onPressed: () => _push(room: false),
                    child: const Text('Push account'),
                  ),
                  OutlinedButton(
                    onPressed: () => _pull(room: false),
                    child: const Text('Pull account'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Restart the app after changing the project URL. Paste supabase/schema.sql into the Supabase SQL editor once.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _Panel(
          title: 'Playlists file',
          child: Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => unawaited(importUserLibrary(context, ref)),
                child: const Text('Import'),
              ),
              OutlinedButton(
                onPressed: () => unawaited(exportUserLibrary(context, ref)),
                child: const Text('Export'),
              ),
            ],
          ),
        ),
        _Panel(
          title: 'About',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$kAppName  $kAppVersion',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Device ${settings.deviceId}',
                style: AppTheme.tabular.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Lyrics come from LRCLIB. Audio plays through just_audio, with libmpv on Linux and a media notification on Android.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _update(AppSettings Function(AppSettings current) edit) {
    unawaited(ref.read(settingsProvider.notifier).update(edit));
  }

  Future<void> _saveFields() async {
    await ref
        .read(settingsProvider.notifier)
        .update(
          (current) => current.copyWith(
            manifestUrl: _manifest.text.trim(),
            localLibraryPath: _local.text.trim(),
            cloudBaseUrl: _cloud.text.trim(),
            supabaseUrl: _supabaseUrl.text.trim(),
            supabaseAnonKey: _anon.text.trim(),
            syncRoomCode: normalizeRoomCode(_room.text),
            restSyncBaseUrl: _rest.text.trim(),
          ),
        );
  }

  Future<void> _refreshCloud() async {
    await _saveFields();
    final error = await ref.read(libraryProvider.notifier).refreshCloud();
    if (!mounted) return;
    showNote(context, error ?? 'Manifest refreshed.');
  }

  Future<void> _useBundled() async {
    _local.clear();
    await ref
        .read(settingsProvider.notifier)
        .update((current) => current.copyWith(localLibraryPath: ''));
    await ref.read(libraryProvider.notifier).useBundled();
    if (!mounted) return;
    showNote(context, 'Using the bundled catalog.');
  }

  Future<void> _pickFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Library folder',
      );
      if (path == null) return;
      _local.text = path;
      await _reloadLocal();
    } catch (error) {
      if (!mounted) return;
      showNote(context, 'Could not open the folder picker. $error');
    }
  }

  Future<void> _reloadLocal() async {
    await _saveFields();
    final error = await ref.read(libraryProvider.notifier).reloadLocal();
    if (!mounted) return;
    showNote(context, error ?? 'Loaded library.json from that folder.');
  }

  void _prefer(SourcePreference preference) {
    unawaited(() async {
      await _saveFields();
      await ref
          .read(settingsProvider.notifier)
          .update((current) => current.copyWith(sourcePreference: preference));
    }());
  }

  Future<void> _newRoom() async {
    final code = newRoomCode();
    _room.text = code;
    await _saveFields();
    if (!mounted) return;
    showNote(context, 'Room code $code');
  }

  Future<void> _connect() async {
    await _saveFields();
    final error = await SupabaseGate.ensure(ref.read(settingsProvider));
    if (!mounted) return;
    setState(() {});
    showNote(context, error ?? 'Connected to Supabase.');
  }

  Future<void> _signIn() async {
    await _connect();
    final error = await SupabaseGate.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {});
    showNote(context, error ?? 'Signed in.');
  }

  Future<void> _signUp() async {
    await _connect();
    final error = await SupabaseGate.signUp(_email.text, _password.text);
    if (!mounted) return;
    setState(() {});
    showNote(
      context,
      error ?? 'Account created. Confirm the email if the project requires it.',
    );
  }

  Future<void> _magic() async {
    await _connect();
    final sent = await SupabaseGate.sendMagicLink(_email.text);
    if (!mounted) return;
    if (sent != null) {
      showNote(context, sent);
      return;
    }
    final code = await promptText(
      context,
      title: 'Paste the email code or link',
      confirm: 'Continue',
    );
    if (code == null || code.trim().isEmpty) return;
    final error = await SupabaseGate.exchange(code);
    if (!mounted) return;
    setState(() {});
    showNote(context, error ?? 'Signed in.');
  }

  Future<void> _signOut() async {
    await SupabaseGate.signOut();
    if (!mounted) return;
    setState(() {});
    showNote(context, 'Signed out.');
  }

  Future<void> _push({required bool room}) async {
    await _saveFields();
    final error = room ? await pushCurrent(ref) : await pushAccountNow(ref);
    _status(
      error ??
          (room
              ? 'Pushed this device to the room.'
              : 'Pushed this account library.'),
    );
  }

  Future<void> _pull({required bool room}) async {
    await _saveFields();
    final error = room
        ? await pullRoomNow(ref, force: true)
        : await pullAccountNow(ref, force: true);
    _status(
      error ?? (room ? 'Pulled the room.' : 'Pulled the account library.'),
    );
  }

  void _status(String message) {
    ref.read(syncStatusProvider.notifier).state = message;
    if (!mounted) return;
    showNote(context, message);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
