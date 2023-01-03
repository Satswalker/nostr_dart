import './util.dart';

class Subscription {
  final String id;
  Map<String, dynamic> filters;

  Subscription._({required this.id, required this.filters});

  factory Subscription.init(Map<String, dynamic> filters, {String id = ''}) {
    if (id.isEmpty) {
      id = getRandomHexString();
    }

    return Subscription._(id: id, filters: filters);
  }
}
