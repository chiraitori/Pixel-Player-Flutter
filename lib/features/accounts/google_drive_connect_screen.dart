import 'package:flutter/material.dart';

import '../../core/state/app_controller.dart';
import '../../data/providers/google_drive/google_drive_api_service.dart';
import '../../data/providers/google_drive/google_drive_auth_service.dart';

class GoogleDriveConnectScreen extends StatefulWidget {
  const GoogleDriveConnectScreen({super.key});

  @override
  State<GoogleDriveConnectScreen> createState() =>
      _GoogleDriveConnectScreenState();
}

class _GoogleDriveConnectScreenState extends State<GoogleDriveConnectScreen> {
  static const _configuredClientId = String.fromEnvironment(
    'GOOGLE_DRIVE_WEB_CLIENT_ID',
  );

  final _clientId = TextEditingController();
  GoogleDriveSession? _session;
  GoogleDriveApiService? _api;
  final List<GoogleDriveFolder> _path = const [
    GoogleDriveFolder(id: 'root', name: 'My Drive'),
  ].toList();
  List<GoogleDriveFolder> _folders = const [];
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clientId.text.isEmpty) {
      _clientId.text = AppScope.of(
        context,
      ).stringSetting('google_drive_web_client_id', _configuredClientId);
    }
  }

  @override
  void dispose() {
    _clientId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _busy ? null : _navigateBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_queue_rounded, size: 24, color: colors.secondary),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Google Drive',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _session == null && _busy
            ? const _DriveLoadingContent(key: ValueKey('drive-loading'))
            : _session == null
            ? _SignInContent(
                key: const ValueKey('drive-sign-in'),
                clientId: _clientId,
                error: _error,
                onSignIn: _signIn,
              )
            : Column(
                key: const ValueKey('drive-folder-setup'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                    child: Text(
                      'Select a music folder',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Choose or create a folder to use as your music source',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _path.length,
                      separatorBuilder: (_, _) =>
                          const Icon(Icons.chevron_right_rounded, size: 18),
                      itemBuilder: (context, index) => TextButton(
                        onPressed: _busy
                            ? null
                            : () => _navigateToBreadcrumb(index),
                        child: Text(_path[index].name),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: colors.secondaryContainer,
                      shape: const RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _busy ? null : _createMusicFolder,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.create_new_folder_rounded,
                                color: colors.secondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create "PixelPlayer Music"',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: colors.onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      'Create a new folder here for your music',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colors.onSecondaryContainer
                                                .withValues(alpha: .7),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Material(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ),
                    ),
                  if (_busy)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_folders.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No folders here',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: colors.onSurfaceVariant.withValues(
                                    alpha: .6,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _folders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final folder = _folders[index];
                          return Material(
                            color: colors.surfaceContainer,
                            shape: const RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _openFolder(folder),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: colors.secondaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.folder_rounded,
                                        color: colors.secondary,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        folder.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () => _selectFolder(folder),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        backgroundColor: colors.secondary
                                            .withValues(alpha: .15),
                                        foregroundColor: colors.secondary,
                                      ),
                                      child: const Text(
                                        'Use',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: colors.onSurfaceVariant.withValues(
                                        alpha: .5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _signIn() async {
    final clientId = _clientId.text.trim();
    final controller = AppScope.of(context);
    controller.setStringSetting('google_drive_web_client_id', clientId);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await GoogleDriveAuthService.instance.signIn(
        serverClientId: clientId,
      );
      final api = GoogleDriveApiService(accessToken: session.accessToken);
      final folders = await api.listFolders();
      if (!mounted) return;
      setState(() {
        _session = session;
        _api = api;
        _folders = folders;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder(GoogleDriveFolder folder) async {
    _path.add(folder);
    await _loadFolder(folder.id);
  }

  Future<void> _navigateBack() async {
    if (_session != null && _path.length > 1) {
      _path.removeLast();
      await _loadFolder(_path.last.id);
      return;
    }
    if (mounted) Navigator.maybePop(context);
  }

  Future<void> _navigateToBreadcrumb(int index) async {
    _path.removeRange(index + 1, _path.length);
    await _loadFolder(_path.last.id);
  }

  Future<void> _loadFolder(String parentId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final folders = await _api!.listFolders(parentId: parentId);
      if (mounted) setState(() => _folders = folders);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createMusicFolder() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final folder = await _api!.createFolder(
        name: 'PixelPlay Music',
        parentId: _path.last.id,
      );
      if (!mounted) return;
      await _selectFolder(folder);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectFolder(GoogleDriveFolder folder) async {
    final session = _session;
    final api = _api;
    if (session == null || api == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await api.listAudioFiles(folderId: folder.id);
      if (!mounted) return;
      AppScope.of(context)
        ..setStringSetting('google_drive_folder_id', folder.id)
        ..setStringSetting('google_drive_folder_name', folder.name)
        ..setStringSetting(
          'account_google_drive_label',
          session.account.displayName ?? session.account.email,
        )
        ..setBoolSetting('account_google_drive_connected', true)
        ..replaceGoogleDriveLibrary(files, accessToken: session.accessToken);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }
}

class _SignInContent extends StatelessWidget {
  const _SignInContent({
    required this.clientId,
    required this.error,
    required this.onSignIn,
    super.key,
  });

  final TextEditingController clientId;
  final String? error;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: colors.secondaryContainer,
                child: Icon(
                  Icons.cloud_queue_rounded,
                  size: 40,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Connect Google Drive',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stream music files directly from your Google Drive',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              if (clientId.text.isEmpty) ...[
                const SizedBox(height: 28),
                TextField(
                  controller: clientId,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'OAuth Web client ID',
                    hintText: '…apps.googleusercontent.com',
                    helperText:
                        'Register com.chiraitori.pixelplay and its signing SHA in Google Cloud.',
                    helperMaxLines: 3,
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                Material(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      error!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ),
              ],
              SizedBox(height: clientId.text.isEmpty ? 22 : 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: onSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.secondary,
                    foregroundColor: colors.onSecondary,
                    shape: const RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                  child: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriveLoadingContent extends StatelessWidget {
  const _DriveLoadingContent({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: colors.secondary),
          const SizedBox(height: 16),
          Text(
            'Setting up Google Drive…',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
