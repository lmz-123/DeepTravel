import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/config/app_config.dart';
import '../../data/travel_plan_store.dart';
import '../experience_providers.dart';

final travelStoreProvider = FutureProvider<TravelPlanStore?>((ref) async {
  final user = ref.watch(currentUserIdProvider);
  if (user == null) return null;
  var disposed = false;
  TravelPlanStore? store;
  ref.onDispose(() {
    disposed = true;
    final opened = store;
    if (opened != null) unawaited(opened.close());
  });
  store = await TravelPlanStore.open(
      await getApplicationSupportDirectory(), '${AppConfig.apiBaseUrl}|$user');
  if (disposed) {
    await store.close();
    return null;
  }
  return store;
});
final travelPlansProvider = FutureProvider<List<TravelPlan>>((ref) async =>
    await (await ref.watch(travelStoreProvider.future))?.plans() ?? []);
final travelPlanProvider = FutureProvider.family<TravelPlan?, String>(
    (ref, id) async => (await ref.watch(travelStoreProvider.future))?.plan(id));

void refreshTravel(WidgetRef ref, String id) {
  ref.invalidate(travelPlansProvider);
  ref.invalidate(travelPlanProvider(id));
}
