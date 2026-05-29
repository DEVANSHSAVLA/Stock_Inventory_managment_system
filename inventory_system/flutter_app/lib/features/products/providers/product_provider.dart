import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_urls.dart';
import '../../../shared/models/product_model.dart';

class ProductsNotifier extends StateNotifier<AsyncValue<List<VariantModel>>> {
  ProductsNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch({String? search}) async {
    state = const AsyncValue.loading();
    try {
      final response = await DioClient().dio.get(
        ApiUrls.variants,
        queryParameters: search != null ? {'search': search} : null,
      );
      final results = (response.data['data']['results'] as List)
          .map((e) => VariantModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final productsProvider = StateNotifierProvider.autoDispose<ProductsNotifier, AsyncValue<List<VariantModel>>>(
  (ref) => ProductsNotifier(),
);
