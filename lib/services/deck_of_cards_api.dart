import 'dart:convert';

import 'package:http/http.dart' as http;

class DeckOfCardsApi {
  static const String _baseUrl = 'https://deckofcardsapi.com/api/deck';

  Future<List<Map<String, dynamic>>> fetchStandardDeckCards() async {
    final response = await http.get(Uri.parse('$_baseUrl/new/draw/?count=52'));

    if (response.statusCode != 200) {
      throw Exception('Deck API request failed with ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final success = json['success'] as bool? ?? false;
    if (!success) {
      throw Exception('Deck API returned success=false');
    }

    final cards = json['cards'] as List<dynamic>? ?? <dynamic>[];
    return cards
        .whereType<Map<String, dynamic>>()
        .map((card) => card)
        .toList(growable: false);
  }
}
