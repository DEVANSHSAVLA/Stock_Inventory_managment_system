import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../shared/models/stock_model.dart';

class StockEntriesNotifier extends StateNotifier<AsyncValue<List<StockEntryModel>>> {
  StockEntriesNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Map<String, dynamic> _filters = {};

  void setFilters(Map<String, dynamic> filters) {
    _filters = filters;
    fetch();
  }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final response = await DioClient().dio.get(ApiUrls.stockEntries, queryParameters: _filters);
      final results = (response.data['data']['results'] as List)
          .map((e) => StockEntryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> approve(int entryId) async {
    try {
      await DioClient().dio.post(ApiUrls.stockApprove(entryId));
      fetch();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final stockEntriesProvider = StateNotifierProvider.autoDispose<StockEntriesNotifier, AsyncValue<List<StockEntryModel>>>(
  (ref) => StockEntriesNotifier(),
);

class LocationsNotifier extends StateNotifier<AsyncValue<List<LocationModel>>> {
  LocationsNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      final response = await DioClient().dio.get(ApiUrls.locations);
      final results = (response.data['data']['results'] as List)
          .map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final locationsProvider = StateNotifierProvider<LocationsNotifier, AsyncValue<List<LocationModel>>>(
  (ref) => LocationsNotifier(),
);
