import 'package:smart_iptv_pro/models/filters.dart';
import 'package:smart_iptv_pro/models/node.dart';
import 'package:smart_iptv_pro/models/view_type.dart';

class HomeManager {
  final Filters filters;
  final Node? node;
  HomeManager({required this.filters, this.node});
  static HomeManager defaultManager() {
    return HomeManager(
      filters: Filters(
        viewType: ViewType.all,
        page: 1,
        useKeywords: false,
      ),
      node: null,
    );
  }
}
