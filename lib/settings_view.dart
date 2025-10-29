import 'package:flutter/material.dart';
import 'package:smart_iptv_pro/backend/settings_service.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:smart_iptv_pro/confirm_delete.dart';
import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/select_dialog.dart';
import 'package:smart_iptv_pro/edit_dialog.dart';
import 'package:smart_iptv_pro/loading.dart';
import 'package:smart_iptv_pro/home.dart';
import 'package:smart_iptv_pro/models/home_manager.dart';
import 'package:smart_iptv_pro/models/id_data.dart';
import 'package:smart_iptv_pro/models/settings.dart';
import 'package:smart_iptv_pro/models/source.dart';
import 'package:smart_iptv_pro/models/source_type.dart';
import 'package:smart_iptv_pro/models/view_type.dart';
import 'package:smart_iptv_pro/error.dart';
import 'package:smart_iptv_pro/setup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_iptv_pro/downloads_view.dart';
import 'package:smart_iptv_pro/services/downloads_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsView> {
  Settings settings = Settings();
  List<Source> sources = [];
  bool loading = true;
  String _sourceCodeUrl() {
    try {
      final v = dotenv.dotenv.env['SOURCE_CODE_URL'];
      return (v != null && v.isNotEmpty) ? v : 'https://example.com/source';
    } catch (_) {
      return 'https://example.com/source';
    }
  }
  @override
  void initState() {
    super.initState();
    initAsync();
  }

  Future<void> _showMetadataProviderDialog() async {
    await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return SelectDialog(
              title: "Metadata provider",
              data: [
                IdData(id: 0, data: 'OMDB (default)'),
                IdData(id: 1, data: 'TMDB'),
              ],
              action: (id) async {
                setState(() {
                  settings.metadataProvider = id == 1 ? 'tmdb' : 'omdb';
                });
                await updateSettings();
                Navigator.of(context).pop();
              });
        });
  }

  Future<void> initAsync() async {
    var results =
        await Future.wait([SettingsService.getSettings(), Sql.getSources()]);
    setState(() {
      settings = results[0] as Settings;
      sources = results[1] as List<Source>;
      loading = false;
    });
  }

  void updateView(ViewType view) {
    if (view != ViewType.settings) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              Home(home: HomeManager(filters: Filters(viewType: view))),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        ),
        (route) => false,
      );
    }
  }

  Future<void> showEditDialog(BuildContext context, final Source source) async {
    await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (builder) =>
            EditDialog(source: source, afterSave: reloadSources));
  }

  Future<void> _showDefaultViewDialog(BuildContext context) async {
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return SelectDialog(
              title: "Default view",
              data: ViewType.values
                  .take(4)
                  .map((x) => IdData(id: x.index, data: x.name))
                  .toList(),
              action: (view) {
                setState(() {
                  settings.defaultView = ViewType.values[view];
                  updateSettings();
                });
                Navigator.of(context).pop();
              });
        });
  }

  Future<void> toggleSource(Source source) async {
    await Error.tryAsyncNoLoading(
        () async => await Sql.setSourceEnabled(!source.enabled, source.id!),
        context);
    await reloadSources();
  }

  Widget getSource(Source source) {
    return Card(
        margin: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5), // Spacing around the tile
        elevation: 5,
        color: source.enabled
            ? Theme.of(context).colorScheme.surfaceContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListTile(
          onLongPress: () => toggleSource(source),
          contentPadding: const EdgeInsets.only(left: 20),
          title: Text(source.name),
          subtitle: Text(getSourceTypeString(source.sourceType)),
          trailing: Row(
            mainAxisSize:
                MainAxisSize.min, // Ensures the row takes up minimal space
            children: [
              Offstage(
                  offstage: source.sourceType == SourceType.m3u,
                  child: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      await Error.tryAsync(() async {
                        await Utils.refreshSource(source);
                      }, context, "Source has been refreshed successfully");
                    },
                  )),
              Offstage(
                  offstage: source.sourceType == SourceType.m3u,
                  child: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async =>
                        await showEditDialog(context, source),
                  )),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async => await showConfirmDeleteDialog(source),
              ),
            ],
          ),
        ));
  }

  Future<void> showConfirmDeleteDialog(Source source) async {
    await showDialog(
        barrierDismissible: true,
        context: context,
        builder: (builder) => ConfirmDelete(
            type: "source",
            name: source.name,
            confirm: () async {
              await Error.tryAsync(
                  () async => await Sql.deleteSource(source.id!),
                  context,
                  "Successfully deleted source");
              await reloadSources();
              if (sources.isEmpty) {
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const Setup()),
                    (route) => false);
              }
            }));
  }

  Future<void> reloadSources() async {
    await Error.tryAsyncNoLoading(
        () async => sources = await Sql.getSources(), context);
    setState(() {
      sources;
    });
  }

  Future<void> updateSettings() async {
    await Error.tryAsyncNoLoading(
        () async => await SettingsService.updateSettings(settings), context);
  }

  Future<void> _showTmdbKeyDialog() async {
    final controller = TextEditingController(text: settings.tmdbApiKey);
    await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
              title: const Text('TMDB API Key'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter TMDB API Key'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () async {
                      setState(() {
                        settings.tmdbApiKey = controller.text.trim();
                      });
                      await updateSettings();
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Save')),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: Visibility(
          visible: !loading,
          child: Loading(
              child: SafeArea(
                  child: Padding(
                      padding:
                          const EdgeInsetsDirectional.symmetric(vertical: 10),
                      child: ListView(
                        children: [
                          const SizedBox(height: 10),
                          const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Text('Settings',
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold))),
                          const SizedBox(height: 10),
                          ListTile(
                              title: const Text("Default view"),
                              subtitle:
                                  Text(viewTypeToString(settings.defaultView)),
                              onTap: () async =>
                                  await _showDefaultViewDialog(context)),
                          ListTile(
                            title: const Text('Metadata provider'),
                            subtitle: Text(settings.metadataProvider == 'tmdb'
                                ? 'TMDB'
                                : 'OMDB'),
                            onTap: _showMetadataProviderDialog,
                          ),
                          ListTile(
                            title: const Text('TMDB API Key'),
                            subtitle: Text(settings.tmdbApiKey.isNotEmpty
                                ? 'Configured'
                                : 'Not set'),
                            trailing: const Icon(Icons.edit),
                            onTap: _showTmdbKeyDialog,
                          ),
                          ListTile(
                            title: const Text("Refresh sources on start"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: settings.refreshOnStart,
                                  onChanged: (bool value) {
                                    setState(() {
                                      settings.refreshOnStart = value;
                                    });
                                    updateSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                          ListTile(
                            title: const Text("Show livestreams"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: settings.showLivestreams,
                                  onChanged: (bool value) {
                                    setState(() {
                                      settings.showLivestreams = value;
                                    });
                                    updateSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                          ListTile(
                            title: const Text("Show movies"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: settings.showMovies,
                                  onChanged: (bool value) {
                                    setState(() {
                                      settings.showMovies = value;
                                    });
                                    updateSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                          ListTile(
                            title: const Text("Show series"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: settings.showSeries,
                                  onChanged: (bool value) {
                                    setState(() {
                                      settings.showSeries = value;
                                    });
                                    updateSettings();
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text('Downloads'),
                            subtitle: const Text('View and manage downloaded items'),
                            trailing: const Icon(Icons.download),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => const DownloadsView(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                  transitionsBuilder: (context, a, b, child) => child,
                                ),
                              );
                            },
                          ),
                          ListTile(
                            title: const Text('Clear all downloads'),
                            trailing: const Icon(Icons.delete_forever),
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Clear all downloads?'),
                                  content: const Text('This will delete all downloaded files from your device.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await DownloadsService.clearAllDownloads();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cleared downloads')),
                                  );
                                }
                              }
                            },
                          ),
                          const Divider(),
                          const Padding(
                              padding: EdgeInsets.only(left: 10),
                              child: Text('About',
                                  style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold))),
                          ListTile(
                            title: const Text('Source code'),
                            subtitle: Text(_sourceCodeUrl()),
                            trailing: const Icon(Icons.launch),
                            onTap: () async {
                              final uri = Uri.parse(_sourceCodeUrl());
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            },
                          ),
                          ListTile(
                            title: const Text('Legal disclaimer'),
                            subtitle: const Text(
                                'SmartIPTV Pro+ does not provide or host any content.'),
                            trailing: const Icon(Icons.info_outline),
                            onTap: () async {
                              await showDialog(
                                context: context,
                                builder: (_) => const AlertDialog(
                                  title: Text('Legal disclaimer'),
                                  content: Text(
                                      'SmartIPTV Pro+ does not provide or host any content. You must supply your own playlists or Xtream credentials. You are solely responsible for the content you access and stream.'),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            title: const Text('Licenses'),
                            trailing: const Icon(Icons.description),
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: 'SmartIPTV Pro+',
                            ),
                          ),
                          const Divider(),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Padding(
                                    padding: EdgeInsets.only(left: 10),
                                    child: Text('Sources',
                                        style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold))),
                                Row(children: [
                                  IconButton(
                                      onPressed: () async => await Error.tryAsync(
                                          () async =>
                                              await Utils.refreshAllSources(),
                                          context,
                                          "Successfully refreshed all sources"),
                                      icon: const Icon(Icons.refresh)),
                                  IconButton(
                                      onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => const Setup(
                                                    showAppBar: true,
                                                  ))),
                                      icon: const Icon(Icons.add))
                                ])
                              ]),
                          const SizedBox(height: 10),
                          ...sources.map(getSource)
                        ],
                      ))))),
    );
  }
}
