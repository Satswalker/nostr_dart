import 'dart:convert';
import 'package:http/http.dart';
import 'package:mockito/annotations.dart';
import 'relay_info.dart';

@GenerateNiceMocks([MockSpec<RelayInfoProvider>()])
class RelayInfoProvider {
  final Client http;

  RelayInfoProvider({required this.http});

  Future<RelayInfo> get(String url) async {
    try {
      final response = await http.get(Uri.parse(url).replace(scheme: 'https'),
          headers: {'Accept': 'application/nostr+json'});
      final decodedResponse = jsonDecode(response.body) as Map;
      return RelayInfo.fromJson(decodedResponse);
    } finally {
      http.close();
    }
  }
}
