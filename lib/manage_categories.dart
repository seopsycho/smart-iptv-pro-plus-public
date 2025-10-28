import 'package:flutter/material.dart';
import 'package:open_tv/backend/sql.dart';
import 'package:open_tv/models/channel.dart';
import 'package:open_tv/models/filters.dart';
import 'package:open_tv/models/media_type.dart';
import 'package:open_tv/models/view_type.dart';

class ManageCategoriesPage extends StatefulWidget {
  final List<int> sourceIds;
  final List<MediaType> mediaTypes;
  const ManageCategoriesPage({super.key, required this.sourceIds, required this.mediaTypes});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  bool _loading = true;
  List<Channel> _cats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await Sql.searchGroupIncludeHidden(Filters(
      viewType: ViewType.categories,
      mediaTypes: widget.mediaTypes,
      sourceIds: widget.sourceIds,
      page: 1,
      useKeywords: false,
    ));
    setState(() {
      _cats = list;
      _loading = false;
    });
  }

  Future<void> _toggleHidden(Channel c) async {
    final hidden = await Sql.getGroupHidden(c.id!);
    await Sql.setGroupHidden(c.id!, !hidden);
    await _load();
  }

  Future<void> _saveOrder() async {
    await Sql.reorderGroups(_cats.map((e) => e.id!).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            onPressed: _saveOrder,
            icon: const Icon(Icons.save),
            tooltip: 'Save Order',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _cats.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _cats.removeAt(oldIndex);
                _cats.insert(newIndex, item);
                setState(() {});
              },
              itemBuilder: (context, index) {
                final c = _cats[index];
                return ListTile(
                  key: ValueKey('cat-${c.id}'),
                  title: Text(c.name),
                  tileColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(12)),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FutureBuilder<bool>(
                          future: Sql.getGroupHidden(c.id!),
                          builder: (context, snap) {
                            final hidden = snap.data == true;
                            return TextButton.icon(
                              onPressed: () => _toggleHidden(c),
                              icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
                              label: Text(hidden ? 'Unhide' : 'Hide'),
                            );
                          }),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
