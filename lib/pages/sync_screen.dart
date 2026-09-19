import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mars_thoughts/services/service_locator.dart';
import 'package:mars_thoughts/sync/sync_service.dart';
import 'package:mars_thoughts/theme/theme_constants.dart';
import 'package:mars_thoughts/util/time_format.dart';

/// Pairing and status for the personal flavor's sync. Reached from Settings;
/// never built in the store flavor (the row that links here is gated).
///
/// Three independent steps: the hub (URL + device token), the shared
/// encryption key (generate on the first device, paste on every other), and
/// then sync itself. Each step shows what it has and what it still needs.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _sync = getIt<SyncService>();

  String? _deviceId;
  bool _hasKey = false;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final deviceId = await _sync.deviceId;
    final hasKey = await _sync.hasEncryptionKey;
    if (!mounted) return;
    setState(() {
      _deviceId = deviceId;
      _hasKey = hasKey;
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _pairHub() async {
    final result = await _prompt(
      title: 'Hub',
      fields: const ['Server URL', 'Device token'],
      initial: [_sync.serverUrl ?? 'https://', ''],
    );
    if (result == null) return;
    await _guard(() async {
      await _sync.pairDevice(serverUrl: result[0], token: result[1]);
      _message = 'Paired as "${await _sync.deviceId}"';
    });
  }

  Future<void> _generateKey() async {
    final confirmed = await _confirm(
      'Generate a new key?',
      'Only do this on the first device. Every other device must be given '
          'this exact key — and the hub can never recover it, so back it up.',
    );
    if (!confirmed) return;
    await _guard(() async {
      final key = await _sync.generateEncryptionKey();
      await _showKey(key);
    });
  }

  Future<void> _importKey() async {
    final result = await _prompt(
      title: 'Encryption key',
      fields: const ['Key from your first device'],
      initial: const [''],
    );
    if (result == null) return;
    await _guard(() async {
      await _sync.importEncryptionKey(result[0]);
      _message = 'Key stored';
    });
  }

  Future<void> _showKey([String? key]) async {
    final value = key ?? await _sync.exportEncryptionKey();
    if (value == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encryption key'),
        content: SelectableText(
          value,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _unpair() async {
    final confirmed = await _confirm(
      'Unpair this device?',
      'Removes the hub pairing and the encryption key from this device. '
          'Thoughts stay where they are, here and on the hub.',
    );
    if (!confirmed) return;
    await _guard(_sync.unpair);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          child: ValueListenableBuilder<SyncStatus>(
            valueListenable: _sync.statusNotifier,
            builder: (context, status, _) {
              return ListView(
                children: [
                  Text(
                    'Sync',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _Step(
                    label: 'Hub',
                    detail: _deviceId == null
                        ? 'Not paired'
                        : '${_sync.serverUrl}\nas "$_deviceId"',
                    action: _deviceId == null ? 'Pair' : 'Re-pair',
                    onTap: _busy ? null : _pairHub,
                  ),
                  _Step(
                    label: 'Encryption key',
                    detail: _hasKey ? 'Stored on this device' : 'Missing',
                    action: _hasKey ? 'Show' : 'Generate',
                    onTap: _busy ? null : (_hasKey ? _showKey : _generateKey),
                    secondaryAction: _hasKey ? null : 'Paste',
                    onSecondaryTap: _busy || _hasKey ? null : _importKey,
                  ),
                  _Step(
                    label: 'Status',
                    detail: _describe(status),
                    action: status.isPaired ? 'Sync now' : null,
                    onTap: _busy || status.phase == SyncPhase.syncing
                        ? null
                        : _sync.syncNow,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      _message!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: COLOR_SECONDARY,
                      ),
                    ),
                  ],
                  if (_deviceId != null || _hasKey) ...[
                    const SizedBox(height: 48),
                    _Step(
                      label: 'Unpair',
                      detail: 'Forget hub and key on this device',
                      action: 'Unpair',
                      onTap: _busy ? null : _unpair,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _describe(SyncStatus status) {
    final last = status.lastSyncedAt == null
        ? 'never synced'
        : 'last sync ${formatThoughtTime(status.lastSyncedAt!)}';
    return switch (status.phase) {
      SyncPhase.unpaired => 'Finish pairing above',
      SyncPhase.syncing => 'Syncing…',
      SyncPhase.idle => last,
      SyncPhase.error => '${status.error}\n$last',
    };
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(
          body,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<List<String>?> _prompt({
    required String title,
    required List<String> fields,
    required List<String> initial,
  }) async {
    final controllers = [
      for (var i = 0; i < fields.length; i++)
        TextEditingController(text: initial[i]),
    ];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fields.length; i++)
              TextField(
                controller: controllers[i],
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300),
                decoration: InputDecoration(
                  labelText: fields[i],
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: COLOR_SECONDARY,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              [for (final c in controllers) c.text],
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in controllers) {
      c.dispose();
    }
    return result;
  }
}

class _Step extends StatelessWidget {
  final String label;
  final String detail;
  final String? action;
  final VoidCallback? onTap;
  final String? secondaryAction;
  final VoidCallback? onSecondaryTap;

  const _Step({
    required this.label,
    required this.detail,
    this.action,
    this.onTap,
    this.secondaryAction,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w300,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    color: COLOR_SECONDARY,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            _ActionText(label: action!, onTap: onTap),
          if (secondaryAction != null) ...[
            const SizedBox(width: 16),
            _ActionText(label: secondaryAction!, onTap: onSecondaryTap),
          ],
        ],
      ),
    );
  }
}

class _ActionText extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ActionText({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: onTap == null ? COLOR_SECONDARY : primary,
          ),
        ),
      ),
    );
  }
}
