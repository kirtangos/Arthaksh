import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logging/logging.dart';

class Fact {
  final String id;
  final String text;
  final String? category;
  final bool active;
  final String description; // Added description field

  Fact({
    required this.id,
    required this.text,
    this.category,
    this.active = true,
    this.description = '',
  });

  factory Fact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Fact(
      id: doc.id,
      text: data['text'] ?? data['description'] ?? '', // Fallback to description if text is not present
      category: data['category'],
      active: data['active'] ?? true,
      description: data['description'] ?? data['text'] ?? '', // Fallback to text if description is not present
    );
  }
  
  // Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'description': description,
      'category': category,
      'active': active,
    };
  }
}

class FactsService {
  static const String _lastShownFactKey = 'last_shown_fact';
  static const String _recentFactsKey = 'recent_facts';
  static const String _factsShownThisSessionKey = 'facts_shown_this_session';
  static const int _maxRecentFacts = 5; // Keep track of last 5 shown facts

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _recentFactIds = [];
  bool _factsShownThisSession = false;

  Future<void> _loadRecentFacts() async {
    final prefs = await SharedPreferences.getInstance();
    _recentFactIds = prefs.getStringList(_recentFactsKey) ?? [];
  }

  Future<void> _loadSessionState() async {
    final prefs = await SharedPreferences.getInstance();
    _factsShownThisSession = prefs.getBool(_factsShownThisSessionKey) ?? false;
  }

  Future<void> _updateRecentFacts(String factId) async {
    _recentFactIds.insert(0, factId);
    if (_recentFactIds.length > _maxRecentFacts) {
      _recentFactIds = _recentFactIds.sublist(0, _maxRecentFacts);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentFactsKey, _recentFactIds);
  }

  Future<void> _markFactsShownThisSession() async {
    _factsShownThisSession = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_factsShownThisSessionKey, true);
  }
  
  // Clear fact history (for testing/development)
  static final _logger = Logger('FactsService');

  FactsService() {
    // Configure logging
    Logger.root.level = Level.ALL; // Set the logging level
    Logger.root.onRecord.listen((record) {
      developer.log(
        '${record.level.name}: ${record.time}: ${record.message}',
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }

  Future<void> clearFactHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastShownFactKey);
    await prefs.remove(_recentFactsKey);
    await prefs.remove(_factsShownThisSessionKey);
    _recentFactIds.clear();
    _factsShownThisSession = false;
    _logger.info('Cleared fact history');
  }

  Future<void> _debugLogAllFacts() async {
    try {
      final allFacts = await _firestore.collection('facts').get();
      _logger.fine('=== ALL FACTS IN DATABASE ===');
      for (var doc in allFacts.docs) {
        _logger.fine('ID: ${doc.id}, Active: ${doc['active'] ?? true}, Text: ${doc['text']}');
      }
      _logger.fine('=============================');
    } catch (e) {
      _logger.severe('Error logging all facts', e);
    }
  }

  Future<Fact?> getNextFact() async {
    try {
      await _loadRecentFacts();
      await _loadSessionState();

      // If facts have already been shown this session, return null
      if (_factsShownThisSession) {
        _logger.info('Facts already shown this session, skipping');
        return null;
      }

      _logger.fine('Recent fact IDs: $_recentFactIds');
      
      // Get all active facts
      final querySnapshot = await _firestore
          .collection('facts')
          .get(const GetOptions(source: Source.server));
      
      _logger.fine('Found ${querySnapshot.docs.length} total facts');
      
      if (querySnapshot.docs.isEmpty) {
        return null;
      }
      
      // Get list of all fact IDs
      final allFactIds = querySnapshot.docs.map((doc) => doc.id).toList();
      
      // If no facts shown yet, return a random one
      if (_recentFactIds.isEmpty) {
        final randomIndex = DateTime.now().millisecondsSinceEpoch % allFactIds.length;
        final firstFact = Fact.fromFirestore(querySnapshot.docs[randomIndex]);
        await _updateRecentFacts(firstFact.id);
        await _markFactsShownThisSession(); // Mark that facts have been shown this session
        return firstFact;
      }
      
      // Get the last shown fact ID
      final lastShownId = _recentFactIds.first;
      
      // Filter out the last shown fact from available facts
      final availableFacts = querySnapshot.docs
          .where((doc) => doc.id != lastShownId)
          .toList();
      
      if (availableFacts.isEmpty) {
        // If no other facts available, return null
        return null;
      }
      
      // Select a random fact from available ones
      final random = DateTime.now().millisecondsSinceEpoch % availableFacts.length;
      final nextFactDoc = availableFacts[random];
      final nextFact = Fact.fromFirestore(nextFactDoc);
      
      // Update recent facts with the new fact
      await _updateRecentFacts(nextFact.id);
      await _markFactsShownThisSession(); // Mark that facts have been shown this session

      _logger.fine('Last shown fact: $lastShownId');
      _logger.fine('Selected fact ID: ${nextFact.id}');
      _logger.fine('Updated recent facts: $_recentFactIds');

      return nextFact;
      
    } catch (e) {
      _logger.severe('Error getting next fact', e);
      return null;
    }
  }
  
  // For backward compatibility
  Future<Fact?> getRandomFact() async {
    try {
      await _loadRecentFacts();
      await _loadSessionState();

      // If facts have already been shown this session, return null
      if (_factsShownThisSession) {
        _logger.info('Facts already shown this session, skipping random fact');
        return null;
      }

      await _debugLogAllFacts();
      _logger.fine('Recent fact IDs: $_recentFactIds');
      
      // Get all facts
      final querySnapshot = await _firestore
          .collection('facts')
          .orderBy(FieldPath.documentId)
          .get(const GetOptions(source: Source.server));
      
      _logger.fine('Found ${querySnapshot.docs.length} total facts');
      
      if (querySnapshot.docs.isEmpty) {
        _logger.warning('No facts found in the database');
        return null;
      }
      
      // Get the last shown fact index from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final lastShownIndex = prefs.getInt('last_shown_fact_index') ?? -1;
      _logger.fine('Last shown fact index: $lastShownIndex');
      
      // Sort facts by ID to ensure consistent order
      final sortedFacts = querySnapshot.docs.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      
      // Calculate next index
      int nextIndex = (lastShownIndex + 1) % sortedFacts.length;
      
      // Get the next fact
      final selectedDoc = sortedFacts[nextIndex];
      
      // Save the new index for next time
      await prefs.setInt('last_shown_fact_index', nextIndex);
      
      // Also save the fact ID for reference
      await prefs.setString(_lastShownFactKey, selectedDoc.id);
      final fact = Fact.fromFirestore(selectedDoc);
      
      print('Selected fact ID: ${fact.id}');
      
      // Update last shown fact ID
      await prefs.setString(_lastShownFactKey, fact.id);
      
      // Update recent facts
      await _updateRecentFacts(fact.id);
      
      // Mark that facts have been shown this session
      await _markFactsShownThisSession();

      _logger.fine('Updated recent facts: $_recentFactIds');

      return fact;
    } catch (e) {
      _logger.severe('Error fetching random fact', e);
      return null;
    }
  }
}

// Global instance of the service
final factsService = FactsService();
