import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:smart_iptv_pro/backend/sql.dart';
import 'package:smart_iptv_pro/backend/utils.dart';
import 'package:smart_iptv_pro/correction_modal.dart';
import 'package:smart_iptv_pro/home.dart';
import 'package:smart_iptv_pro/loading.dart';
import 'package:smart_iptv_pro/models/home_manager.dart';
import 'package:smart_iptv_pro/models/source.dart';
import 'package:smart_iptv_pro/models/source_type.dart';
import 'package:smart_iptv_pro/error.dart';
import 'package:smart_iptv_pro/adaptive/breakpoints.dart';
import 'package:smart_iptv_pro/services/analytics_service.dart';

class Setup extends StatefulWidget {
  final bool showAppBar;
  const Setup({super.key, this.showAppBar = false});

  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  int _selectedIndex = 0;
  final _formKey = GlobalKey<FormBuilderState>();
  bool formValid = false;
  Set<String> existingSourceNames = {};

  Future<bool> showXtreamCorrectionModal(
      String originalUrl, String correctedUrl, List<String> changes) async {
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => CorrectionModal(
              originalUrl: originalUrl,
              correctedUrl: correctedUrl,
              changes: changes,
            ));
    return result ?? false;
  }

  Future<String> fixUrl(String url) async {
    final input = url;
    String original = url.trim();
    var uri = Uri.parse(original);
    List<String> changes = [];
    if (original != input) {
      changes.add("Trimmed whitespace.");
    }

    if (uri.scheme.isEmpty) {
      uri = Uri.parse("https://${uri.toString()}");
      changes.add("Added 'https://' scheme.");
    }
    if (uri.path == "/" || uri.path.isEmpty) {
      final newUri = uri.resolve("player_api.php");
      if (newUri.toString() != uri.toString()) {
        changes.add("Appended 'player_api.php' to the URL path.");
        uri = newUri;
      }
    }
    if (changes.isEmpty) {
      return original;
    }
    final accept =
        await showXtreamCorrectionModal(input, uri.toString(), changes);
    return accept ? uri.toString() : original;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: widget.showAppBar
            ? AppBar(title: const Text("Adding a new source"))
            : null,
        body: Loading(
            child: SafeArea(
                child: FormBuilder(
                    onChanged: () {
                      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                        setState(() {
                          formValid = _formKey.currentState?.isValid == true;
                        });
                      });
                    },
                    key: _formKey,
                    child: Center(
                        child: LayoutBuilder(builder: (context, constraints) {
                      final cls = sizeClassOf(context);
                      final maxW = cls == WindowSizeClass.expanded
                          ? 680.0
                          : (cls == WindowSizeClass.medium ? 560.0 : 480.0);
                      // Log screen view once when the widget is built
                      AnalyticsService.logScreenView('Setup', screenClass: 'Setup');
                      return SizedBox(
                        width: maxW,
                        child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                        ToggleButtons(
                          isSelected: List.generate(
                              3, (index) => index == _selectedIndex),
                          onPressed: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                            WidgetsBinding.instance
                                .addPostFrameCallback((timeStamp) {
                              setState(() {
                                formValid =
                                    _formKey.currentState?.isValid == true;
                              });
                            });
                          },
                          children: const <Widget>[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('Xtream'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('M3U URL'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text('M3U File'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16.0),
                          child: FormBuilderTextField(
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            validator: FormBuilderValidators.compose([
                              FormBuilderValidators.required(),
                              (value) {
                                var trimmed = value?.trim();
                                if (trimmed == null || trimmed.isEmpty) {
                                  return null;
                                }
                                if (existingSourceNames.contains(trimmed)) {
                                  return "Name already exists";
                                }
                                return null;
                              }
                            ]),
                            decoration: const InputDecoration(
                              labelText: 'Name', // Label inside the input
                              prefixIcon: Icon(Icons
                                  .edit), // Icon inside the input (left side)
                              border: OutlineInputBorder(),
                            ),
                            name: 'name',
                          ),
                        ),
                        if (_selectedIndex == SourceType.xtream.index ||
                            _selectedIndex == SourceType.m3uUrl.index)
                          const SizedBox(height: 15),
                        if (_selectedIndex == SourceType.xtream.index ||
                            _selectedIndex == SourceType.m3uUrl.index)
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0),
                              child: FormBuilderTextField(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: FormBuilderValidators.compose([
                                  FormBuilderValidators.required(),
                                  (value) {
                                    final v = value?.trim();
                                    if (v == null || v.isEmpty) return null;
                                    final u = Uri.tryParse(v);
                                    if (u == null || !u.hasScheme) {
                                      return 'Enter a valid URL starting with http:// or https://';
                                    }
                                    final scheme = u.scheme.toLowerCase();
                                    if (scheme != 'http' && scheme != 'https') {
                                      return 'Only http:// or https:// URLs are supported';
                                    }
                                    return null;
                                  }
                                ]),
                                decoration: const InputDecoration(
                                  labelText: 'URL', // Label inside the input
                                  prefixIcon: Icon(Icons
                                      .link), // Icon inside the input (left side)
                                  border: OutlineInputBorder(),
                                ),
                                name: 'url',
                              )),
                        if (_selectedIndex == SourceType.xtream.index)
                          const SizedBox(height: 15),
                        if (_selectedIndex == SourceType.xtream.index)
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0),
                              child: FormBuilderTextField(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: FormBuilderValidators.compose(
                                    [FormBuilderValidators.required()]),
                                decoration: const InputDecoration(
                                  labelText:
                                      'Username', // Label inside the input
                                  prefixIcon: Icon(Icons
                                      .account_circle), // Icon inside the input (left side)
                                  border: OutlineInputBorder(),
                                ),
                                name: 'username',
                              )),
                        if (_selectedIndex == SourceType.xtream.index)
                          const SizedBox(height: 15),
                        if (_selectedIndex == SourceType.xtream.index)
                          Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0),
                              child: FormBuilderTextField(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: FormBuilderValidators.compose(
                                    [FormBuilderValidators.required()]),
                                decoration: const InputDecoration(
                                  labelText:
                                      'Password', // Label inside the input
                                  prefixIcon: Icon(Icons
                                      .password), // Icon inside the input (left side)
                                  border: OutlineInputBorder(),
                                ),
                                name: 'password',
                              )),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: formValid
                                ? Colors.blue
                                : Colors.grey, // Disabled color
                            foregroundColor: Colors.white, // Text color
                          ),
                          onPressed: () async {
                            final sourceName = (_formKey.currentState
                                    ?.instantValue["name"] as String)
                                .trim();
                            if (await Sql.sourceNameExists(sourceName)) {
                              existingSourceNames.add(sourceName);
                            }
                            if (_formKey.currentState?.saveAndValidate() ==
                                false) {
                              return;
                            }
                            final sourceType =
                                SourceType.values[_selectedIndex];
                            var url = sourceType == SourceType.m3u
                                ? (await FilePicker.platform.pickFiles())
                                    ?.files
                                    .single
                                    .path
                                : (_formKey.currentState?.value["url"]
                                    as String);
                            if (sourceType == SourceType.m3u && url == null) {
                              return;
                            }
                            if (sourceType == SourceType.xtream) {
                              url = await fixUrl(url!);
                            }

                            // Steps for progress dialog
                            final List<String> steps =
                                sourceType == SourceType.xtream
                                    ? [
                                        "Checking server status",
                                        "Fetching live streaming categories",
                                        "Fetching live streaming Channels",
                                        "Fetching live movie categories",
                                        "Fetching live films",
                                        "Fetching live series categories",
                                        "Fetching live series",
                                        "Fetching Information",
                                      ]
                                    : ["Fetching Information"];
                            final completed = <String>{};
                            late StateSetter setDialogState;

                            final dialogFuture = showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    setDialogState = setState;
                                    return AlertDialog(
                                      title: const Text("Loading Playlist"),
                                      content: SizedBox(
                                        width: 320,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: steps
                                              .map((s) => ListTile(
                                                    dense: true,
                                                    leading: completed
                                                            .contains(s)
                                                        ? const Icon(
                                                            Icons.check_circle,
                                                            color: Colors.green)
                                                        : const SizedBox(
                                                            width: 24,
                                                            height: 24,
                                                            child:
                                                                CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2),
                                                          ),
                                                    title: Text(s),
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              completed.length == steps.length
                                                  ? () => Navigator.pop(context)
                                                  : null,
                                          child: const Text("Done"),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );

                            final result =
                                await Error.tryAsyncNoLoading(() async {
                              await Utils.processSource(
                                Source(
                                  name: sourceName,
                                  sourceType: sourceType,
                                  url: url,
                                  username: sourceType == SourceType.xtream
                                      ? (_formKey.currentState
                                              ?.value["username"] as String)
                                          .trim()
                                      : null,
                                  password: sourceType == SourceType.xtream
                                      ? (_formKey.currentState
                                              ?.value["password"] as String)
                                          .trim()
                                      : null,
                                ),
                                false,
                                (label, done) {
                                  if (done && steps.contains(label)) {
                                    completed.add(label);
                                    setDialogState(() {});
                                  }
                                },
                              );
                            }, context, true, "Successfully added source");

                            await dialogFuture;

                            if (result.success) {
                              // Log playlist add
                              try {
                                await AnalyticsService.logPlaylistAdd(
                                  sourceType: getSourceTypeString(sourceType),
                                  sourceName: sourceName,
                                  urlType: sourceType == SourceType.xtream
                                      ? 'xtream'
                                      : (sourceType == SourceType.m3uUrl ? 'm3u_url' : 'm3u_file'),
                                );
                              } catch (_) {}
                              if (!mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Home(home: HomeManager.defaultManager()),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text("Submit"),
                        )
                      ]),
                    ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
