import 'package:flutter/foundation.dart';

import '../core/services/supabase_service.dart';
import '../data/models/user_route.dart';

class CommunityRoutesProvider extends ChangeNotifier {
  final SupabaseService _supa = SupabaseService.instance;
  List<UserRoute> _routes = [];
  bool _loading = false;

  List<UserRoute> get routes => List.unmodifiable(_routes);
  bool get isLoading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _routes = await _supa.fetchRoutes();
    _loading = false;
    notifyListeners();
  }

  Future<void> publish(UserRoute route) async {
    _routes = [route, ..._routes];
    notifyListeners();
    await _supa.postRoute(route);
  }

  Future<void> like(String routeId) async {
    _routes = _routes
        .map((r) => r.id == routeId
            ? r.copyWith(likes: r.likes + 1)
            : r)
        .toList();
    notifyListeners();
    await _supa.likeRoute(routeId);
  }
}
