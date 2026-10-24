import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

/// Run separately from the sample app so no wallet or relay is initialized.
void main() => runApp(
      MaterialApp(
        title: 'NDK Passkey Lab',
        theme: ThemeData(colorSchemeSeed: const Color(0xff6554c0)),
        home: const PasskeyDemo(),
      ),
    );

class PasskeyDemo extends StatefulWidget {
  const PasskeyDemo({super.key});

  @override
  State<PasskeyDemo> createState() => _PasskeyDemoState();
}

class _PasskeyDemoState extends State<PasskeyDemo> {
  static const _metadataKey = 'ndk-passkey-demo-public-metadata';
  final _storage = const FlutterSecureStorage();
  final _provider = PlatformPasskeyProvider();
  Accounts _accounts = Accounts(const Bip340EventSignerFactory());
  PasskeyAccount? _remembered;
  String _status = 'Loading saved public metadata…';
  String? _eventId;
  bool _busy = true;
  int _parameter = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _metadataKey);
      if (raw != null) {
        _remembered = PasskeyAccount.fromJson(jsonDecode(raw));
      }
      _status = _remembered == null
          ? 'Create a test account or open a compatible passkey.'
          : 'Account remembered. Open its passkey to check recovery.';
    } catch (_) {
      _status = 'Saved metadata could not be loaded. Reload before continuing.';
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeSession() async {
    for (final account in _accounts.accounts.values) {
      await account.signer.dispose();
    }
    await _accounts.dispose();
    _accounts = Accounts(const Bip340EventSignerFactory());
    _eventId = null;
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      _status = 'Could not finish: $error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open({required bool create}) => _run(() async {
        await _closeSession();
        final expected = create ? null : _remembered;
        final account = create
            ? await _accounts.createPasskey(
                provider: _provider,
                rpId: Uri.base.host,
                rpName: 'NDK Passkey Lab',
                userName: 'NDK test ${DateTime.now().toIso8601String()}',
                parameterSet: _parameter,
              )
            : await _accounts.loginWithPasskey(
                provider: _provider,
                rpId: Uri.base.host,
                account: expected,
              );
        // Only public metadata is persisted. No private key or PRF output is saved.
        await _storage.write(
          key: _metadataKey,
          value: jsonEncode(account.toJson()),
        );
        _remembered = account;
        _status = create
            ? 'Account created. Close the session, then reopen it to test recovery.'
            : expected == null
                ? 'Compatible passkey opened. Its public key is shown below.'
                : 'Recovery passed: the public key matches your saved account.';
      });

  Future<void> _sign() => _run(() async {
        final event = await _accounts.sign(
          Nip01Event(
            pubKey: _accounts.getPublicKey()!,
            kind: 1,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            tags: [],
            content: 'NDK local passkey test — not published',
          ),
        );
        if (!await Bip340EventVerifier().verify(event)) {
          throw StateError('Event signature did not verify');
        }
        _eventId = event.id;
        _status = 'Signature verified locally. Nothing was published.';
      });

  @override
  void dispose() {
    for (final account in _accounts.accounts.values) {
      account.signer.dispose();
    }
    _accounts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _accounts.getPublicKey();
    return Scaffold(
      appBar: AppBar(title: const Text('NDK Passkey Lab')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Try passkey recovery',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text(
                  'Test accounts only. This uses the proposed passkey format. No relay connection or payment is made.'),
              const SizedBox(height: 20),
              Text('Passkey domain: ${Uri.base.host}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _parameter,
                decoration: const InputDecoration(
                    labelText: 'New account format',
                    border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(
                      value: 1, child: Text('Proposed standard · 01')),
                  DropdownMenuItem(
                      value: 2, child: Text('LaWallet derivation · 02')),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _parameter = value!),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                      onPressed: _busy ? null : () => _open(create: true),
                      child: const Text('Create test account')),
                  OutlinedButton(
                      onPressed: _busy ? null : () => _open(create: false),
                      child: const Text('Open passkey')),
                  OutlinedButton(
                      onPressed: _busy || active == null ? null : _sign,
                      child: const Text('Sign test event')),
                  TextButton(
                    onPressed: _busy || active == null
                        ? null
                        : () => _run(() async {
                              await _closeSession();
                              _status =
                                  'Session closed. Open the passkey again or reload this page.';
                            }),
                    child: const Text('Close session'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Semantics(liveRegion: true, child: Text(_status)),
              if (_remembered != null || active != null) ...[
                const SizedBox(height: 24),
                Text(
                    active == null
                        ? 'Remembered public key'
                        : 'Active public key',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SelectableText(active ?? _remembered!.pubkey),
              ],
              if (_eventId != null) ...[
                const SizedBox(height: 16),
                const Text('Verified event ID'),
                SelectableText(_eventId!),
              ],
              const SizedBox(height: 28),
              const Text(
                  'Use the same domain and passkey when returning. Provider support for PRF and synchronization varies. Stored-key and vault recovery are not part of this small demo.'),
            ],
          ),
        ),
      ),
    );
  }
}
