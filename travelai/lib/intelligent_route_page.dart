import 'package:flutter/material.dart';
import 'services/rag_service.dart';
import 'models/route_knowledge_base.dart';
import 'bus_stops_page.dart';

class IntelligentRoutePage extends StatefulWidget {
  const IntelligentRoutePage({super.key});

  @override
  State<IntelligentRoutePage> createState() => _IntelligentRoutePageState();
}

class _IntelligentRoutePageState extends State<IntelligentRoutePage> {
  final TextEditingController _queryController = TextEditingController();
  final RAGService _ragService = RAGService();

  bool _isLoading = false;
  bool _isInitialized = false;
  String _response = '';
  List<RouteMatch> _matches = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeRAG();
  }

  Future<void> _initializeRAG() async {
    setState(() => _isLoading = true);

    try {
      await _ragService.initialize();
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchRoutes() async {
    final query = _queryController.text.trim();

    if (query.isEmpty) {
      setState(() => _errorMessage = 'Please enter a search query');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get matching routes
      final matches = await _ragService.findSimilarRoutes(query, topK: 3);

      // Generate intelligent response
      final response = await _ragService.generateRouteResponse(query);

      setState(() {
        _matches = matches;
        _response = response;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRouteStops(RouteInfo route) async {
    // Add all stops from this route to the bus stops database
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Route Stops'),
        content: Text(
            'Load all ${route.stops.length} bus stops from "${route.name}" to your tracking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Load Stops'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await RouteKnowledgeBase.addRoute(route);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Loaded ${route.stops.length} stops from ${route.name}'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BusStopsPage()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stops: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Intelligent Route Finder'),
            Text('AI-Powered Search', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              color: Colors.indigo[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 48, color: Colors.indigo[700]),
                    const SizedBox(height: 8),
                    Text(
                      'AI-Powered Route Discovery',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask in natural language about routes and bus stops',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Search Box
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        labelText: 'Ask about routes',
                        hintText:
                            'e.g., "How do I get to NMAMIT?" or "Mangalore to Nitte"',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 2,
                      onSubmitted: (_) => _searchRoutes(),
                    ),
                    const SizedBox(height: 12),

                    // Example queries
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildExampleChip('Mangalore to NMAMIT'),
                        _buildExampleChip('Route to Nitte'),
                        _buildExampleChip('Surathkal stops'),
                        _buildExampleChip('Udupi buses'),
                      ],
                    ),

                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed:
                          _isLoading || !_isInitialized ? null : _searchRoutes,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isLoading ? 'Searching...' : 'Find Routes'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // AI Response
            if (_response.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                color: Colors.green[50],
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Response',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(_response, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],

            // Matching Routes
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Matching Routes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              ..._matches.map((match) => _buildRouteCard(match)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _queryController.text = text;
        _searchRoutes();
      },
      avatar: const Icon(Icons.touch_app, size: 16),
    );
  }

  Widget _buildRouteCard(RouteMatch match) {
    final route = match.route;
    final percentage = (match.similarity * 100).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: match.isGoodMatch ? Colors.green : Colors.orange,
          child: Text('$percentage%', style: const TextStyle(fontSize: 12)),
        ),
        title: Text(
          route.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(route.description),
            if (match.matchedKeywords.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: match.matchedKeywords
                    .map((kw) => Chip(
                          label: Text(kw, style: const TextStyle(fontSize: 10)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bus Stops:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...route.stops.map((stop) => Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 4),
                      child: Row(
                        children: [
                          Text('${stop.sequenceNumber}. '),
                          Expanded(child: Text(stop.name)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _loadRouteStops(route),
                  icon: const Icon(Icons.download),
                  label: const Text('Load These Stops'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}
