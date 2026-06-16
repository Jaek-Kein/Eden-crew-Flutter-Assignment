// ignore_for_file: unused_element, unused_field

import 'dart:convert';

import 'package:dio/dio.dart';

import '../dtos/naver_stock_dtos.dart';

abstract interface class NaverStockDataClient {
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query);

  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  );

  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol);

  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  });
}

class NaverDomesticStockClient implements NaverStockDataClient {
  const NaverDomesticStockClient(this._dio);

  final Dio _dio;

  static const Map<String, String> _defaultHeaders = {
    'accept': 'application/json, text/plain, */*',
    'referer': 'https://m.stock.naver.com/',
    'accept-language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/123.0.0.0 Safari/537.36',
  };

  static Map<String, dynamic> _decodeJsonObjectBody(
    Object? data,
    String contextLabel,
  ) {
    if (data == null) {
      throw FormatException('$contextLabel response body is empty');
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is List<int>) {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException('$contextLabel response is not a JSON object');
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel response body has unsupported shape');
  }

  static Map<String, dynamic> _asStringKeyedMap(
    Object? value,
    String contextLabel,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }

    throw FormatException('$contextLabel is not a JSON object');
  }

  @override
  Future<List<NaverAutocompleteItemDto>> searchStocks(String query) async {
    final response = await _dio.get(
      'https://ac.stock.naver.com/ac',
      queryParameters: {
        'q': query,
        'target': 'stock,ipo,index,marketindicator',
      },
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final json = _decodeJsonObjectBody(response, 'searchStocks');
    final items = json['items'] as List<dynamic>;

    return items
        .map(
          (item) => NaverAutocompleteItemDto.fromJson(
            _asStringKeyedMap(item, 'Naver autocomplete item'),
          ),
        )
        .toList();
  }

  @override
  Future<Map<String, NaverRealtimeQuoteDto>> fetchRealtimeQuotes(
    Iterable<String> symbols,
  ) async {
    final deduped = symbols.toSet().toList();
    if (deduped.isEmpty) {
      return {};
    }

    final query = 'SERVICE_ITEM:${deduped.join(',')}';

    final response = await _dio.get(
      'https:///polling.finance.naver.com/api/realtime',
      queryParameters: {'query': query},
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final json = _decodeJsonObjectBody(response.data, 'fetchRealtimeQuotes');
    final areas = (json['result']?['areas'] as List<dynamic>?) ?? [];

    final result = <String, NaverRealtimeQuoteDto>{};
    for (final area in areas) {
      final datas = (area['datas'] as List<dynamic>?) ?? [];
      for (final row in datas) {
        final dto = NaverRealtimeQuoteDto.fromJson(row as Map<String, dynamic>);
        result[dto.symbol] = dto;
      }
    }

    return result;
  }

  @override
  Future<NaverChartMetadataDto> fetchChartMetadata(String symbol) async {
    final response = await _dio.get(
      'https://stock.naver.com/api/securityFe/api/fchart/domestic/stock/$symbol',
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.plain,
      ),
    );

    final json = _decodeJsonObjectBody(response.data, 'fetchChartMetadata');
    final dto = NaverChartMetadataDto.fromJson(json);

    return dto;
  }

  @override
  Future<NaverDailyHistoryPageDto> fetchDailyHistoryPage({
    required String symbol,
    required int page,
  }) async {
    if (page < 1) throw ArgumentError('Page must be bigger then 1');
    final response = await _dio.get(
      'https://finance.naver.com/item/sise_day.naver',
      queryParameters: {'code': symbol, 'page': page},
      options: Options(
        headers: _defaultHeaders,
        responseType: ResponseType.bytes,
      ),
    );

    final html = latin1.decode(response.data as List<int>);

    final rowRegex = RegExp(
      r'<tr[^>]*>\s*<td[^>]*>\s*<span[^>]*>(\d{4}\.\d{2}\.\d{2})</span>.*?</tr>',
      dotAll: true,
    );
    final numRegex = RegExp(r'[\d,]+');

    final priceInfos = <NaverHistoricalPriceDto>[];

    for (final row in rowRegex.allMatches(html)) {
      final rowHtml = row.group(0)!;
      final nums = numRegex
          .allMatches(rowHtml)
          .map((m) => m.group(0)!)
          .toList();

      //    TD order
      //   - localDate (yyyyMMdd)
      //   - closePrice
      //   - openPrice
      //   - highPrice
      //   - lowPrice
      //   - accumulatedTradingVolume

      final dateStr = nums[0].replaceAll('.', '');

      priceInfos.add(
        NaverHistoricalPriceDto.fromJson({
          'localDate': dateStr,
          'closePrice': nums[1],
          'openPrice': nums[3],
          'highPrice': nums[4],
          'lowPrice': nums[5],
          'accumulatedTradingVolume': nums[6],
        }),
      );
    }

    final lastPageRegex = RegExp(r'page=(\d+)');
    final lastPageMatch = lastPageRegex.allMatches(html);
    final lastPage = lastPageMatch.map((m) => int.tryParse(m.group(1)!) ?? 0).fold(page, (max, n) => n > max ? n : max);

    return NaverDailyHistoryPageDto(
      symbol: symbol,
      page: page,
      lastPage: lastPage,
      priceInfos: priceInfos,
    );
  }
}

double _parseDouble(String value) {
  return double.parse(value.replaceAll(',', ''));
}

int _parseInt(String value) {
  return int.parse(value.replaceAll(',', ''));
}

Map<String, String> naverDesktopLikeHeaders() =>
    Map<String, String>.unmodifiable(NaverDomesticStockClient._defaultHeaders);
