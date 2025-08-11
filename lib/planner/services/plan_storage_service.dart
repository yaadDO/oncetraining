// plan_storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ride_plan.dart';


class PlanStorageService {
  static const _plansKey = 'saved_plans';

  Future<void> savePlan(RidePlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await getPlans();
    final index = plans.indexWhere((p) => p.id == plan.id);

    if (index != -1) {
      plans[index] = plan;
    } else {
      plans.add(plan);
    }

    await prefs.setStringList(
      _plansKey,
      plans.map((p) => p.toJson()).toList(),
    );
  }

  Future<List<RidePlan>> getPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_plansKey);

    if (jsonList == null) return [];

    return jsonList
        .map((json) => RidePlan.fromJson(json))
        .toList();
  }

  Future<void> deletePlan(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final plans = await getPlans();
    plans.removeWhere((plan) => plan.id == id);

    await prefs.setStringList(
      _plansKey,
      plans.map((p) => p.toJson()).toList(),
    );
  }
}