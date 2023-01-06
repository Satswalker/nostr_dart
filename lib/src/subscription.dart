import 'util.dart';

class Subscription {
  final String _id;
  Map<String, dynamic> filters;

  String get id => _id;

  Subscription(this.filters, [String? id]) : _id = id ?? getRandomHexString();
}
