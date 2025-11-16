import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/route_knowledge_base.dart';
import '../models/bus_stop.dart';

/// RAG (Retrieval-Augmented Generation) Service for intelligent route detection
class RAGService {
  static const String _defaultApiKey = 'YOUR_GEMINI_API_KEY_HERE';

  late final GenerativeModel _model;
  late final GenerativeModel _embeddingModel;

  // Cached embeddings for routes
  final Map<String, List<double>> _routeEmbeddings = {};
  List<RouteInfo> _routes = [];

  bool _initialized = false;

  RAGService({String? apiKey}) {
    final key = apiKey ?? _defaultApiKey;

    // Initialize Gemini models
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: key,
    );

    _embeddingModel = GenerativeModel(
      model: 'text-embedding-004',
      apiKey: key,
    );
  }

  /// Initialize the RAG service
  Future<void> initialize() async {
    if (_initialized) return;

    // Load routes from knowledge base
    _routes = await RouteKnowledgeBase.loadRoutes();

    // Generate embeddings for all routes
    for (final route in _routes) {
      try {
        final embedding = await _generateEmbedding(route.getFullText());
        _routeEmbeddings[route.id] = embedding;
      } catch (e) {
        print('Error generating embedding for route ${route.id}: $e');
      }
    }

    _initialized = true;
  }

  /// Generate embedding for text using Gemini
  Future<List<double>> _generateEmbedding(String text) async {
    try {
      final content = [Content.text(text)];
      final result = await _embeddingModel.embedContent(
        content.first,
        taskType: TaskType.retrievalQuery,
      );
      return result.embedding.values;
    } catch (e) {
      print('Embedding generation error: $e');
      // Fallback to simple hash-based embedding
      return _generateSimpleEmbedding(text);
    }
  }

  /// Fallback: Generate simple embedding based on keyword matching
  List<double> _generateSimpleEmbedding(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final embedding = List<double>.filled(384, 0.0);

    for (int i = 0; i < words.length && i < 384; i++) {
      embedding[i] = words[i].hashCode.toDouble() / 1000000;
    }

    return embedding;
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Find routes similar to the query using vector similarity
  Future<List<RouteMatch>> findSimilarRoutes(String query,
      {int topK = 3}) async {
    if (!_initialized) {
      await initialize();
    }

    // Generate embedding for query
    final queryEmbedding = await _generateEmbedding(query);

    // Calculate similarity scores
    final List<RouteMatch> matches = [];

    for (final route in _routes) {
      final routeEmbedding = _routeEmbeddings[route.id];
      if (routeEmbedding == null) continue;

      final similarity = _cosineSimilarity(queryEmbedding, routeEmbedding);

      // Also check keyword matches for better accuracy
      final keywordScore = _calculateKeywordScore(query, route);

      // Combined score (70% similarity, 30% keyword)
      final finalScore = (similarity * 0.7) + (keywordScore * 0.3);

      matches.add(RouteMatch(
        route: route,
        similarity: finalScore,
        matchedKeywords: _getMatchedKeywords(query, route),
      ));
    }

    // Sort by similarity and return top K
    matches.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matches.take(topK).toList();
  }

  /// Calculate keyword match score
  double _calculateKeywordScore(String query, RouteInfo route) {
    final queryWords = query.toLowerCase().split(RegExp(r'\s+'));
    int matches = 0;

    for (final word in queryWords) {
      if (word.length < 3) continue; // Skip short words

      // Check if word appears in route keywords
      for (final keyword in route.keywords) {
        if (keyword.toLowerCase().contains(word) ||
            word.contains(keyword.toLowerCase())) {
          matches++;
          break;
        }
      }

      // Check landmarks
      for (final landmark in route.landmarks) {
        if (landmark.toLowerCase().contains(word) ||
            word.contains(landmark.toLowerCase())) {
          matches++;
          break;
        }
      }
    }

    return matches / max(queryWords.length, 1);
  }

  /// Get matched keywords for display
  List<String> _getMatchedKeywords(String query, RouteInfo route) {
    final queryWords = query.toLowerCase().split(RegExp(r'\s+'));
    final matched = <String>[];

    for (final word in queryWords) {
      if (word.length < 3) continue;

      for (final keyword in route.keywords) {
        if (keyword.toLowerCase().contains(word)) {
          matched.add(keyword);
        }
      }
    }

    return matched.take(5).toList();
  }

  /// Generate intelligent response using RAG
  Future<String> generateRouteResponse(String query) async {
    if (!_initialized) {
      await initialize();
    }

    // Retrieve similar routes
    final matches = await findSimilarRoutes(query, topK: 2);

    if (matches.isEmpty) {
      return 'No matching routes found. Please try a different query.';
    }

    // Build context from retrieved routes
    final context = matches.map((m) {
      final route = m.route;
      return '''
Route: ${route.name}
Description: ${route.description}
Stops: ${route.stops.map((s) => s.name).join(' → ')}
Landmarks: ${route.landmarks.take(5).join(', ')}
''';
    }).join('\n\n');

    // Generate response using LLM
    try {
      final prompt = '''
Based on the following route information:

$context

User Query: $query

Please provide a helpful, concise response about the route including:
1. The best matching route
2. Key bus stops along the way
3. Important landmarks
4. Any helpful travel tips

Keep the response under 150 words.
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'Unable to generate response.';
    } catch (e) {
      // Fallback response without LLM
      final bestMatch = matches.first;
      return '''
Found route: ${bestMatch.route.name}

${bestMatch.route.description}

Key stops: ${bestMatch.route.stops.take(5).map((s) => s.name).join(' → ')}

This route passes through: ${bestMatch.route.landmarks.take(3).join(', ')}.
''';
    }
  }

  /// Extract bus stops from query intelligently
  Future<List<BusStop>> extractBusStops(String query) async {
    if (!_initialized) {
      await initialize();
    }

    final matches = await findSimilarRoutes(query, topK: 1);

    if (matches.isEmpty) {
      return [];
    }

    return matches.first.route.stops;
  }

  /// Suggest route based on start and end locations
  Future<RouteMatch?> suggestRoute(
      String startLocation, String endLocation) async {
    if (!_initialized) {
      await initialize();
    }

    final query = '$startLocation to $endLocation';
    final matches = await findSimilarRoutes(query, topK: 1);

    return matches.isNotEmpty ? matches.first : null;
  }
}

/// Represents a route match with similarity score
class RouteMatch {
  final RouteInfo route;
  final double similarity;
  final List<String> matchedKeywords;

  RouteMatch({
    required this.route,
    required this.similarity,
    required this.matchedKeywords,
  });

  bool get isGoodMatch => similarity > 0.5;
}
