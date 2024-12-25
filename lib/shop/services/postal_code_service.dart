// postal_code_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

class PostalAddress {
  final String prefecture;
  final String city;
  final String street;

  PostalAddress({
    required this.prefecture,
    required this.city,
    required this.street,
  });
}

class PostalCodeService {
  static const String _baseUrl = 'https://zipcloud.ibsnet.co.jp/api/search';

  Future<PostalAddress?> getAddress(String postalCode) async {
    try {
      final cleanPostalCode = postalCode.replaceAll('-', '');
      final response = await http.get(
        Uri.parse('$_baseUrl?zipcode=$cleanPostalCode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] == null) {
          return null;
        }

        final result = data['results'][0];
        return PostalAddress(
          prefecture: result['address1'],
          city: result['address2'],
          street: result['address3'],
        );
      }
      return null;
    } catch (e) {
      throw Exception('郵便番号の検索に失敗しました: $e');
    }
  }
}
