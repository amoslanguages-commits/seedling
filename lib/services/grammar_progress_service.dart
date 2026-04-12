import 'package:shared_preferences/shared_preferences.dart';
import '../models/learning_path_model.dart';

class GrammarProgressService {
  static final GrammarProgressService instance = GrammarProgressService._internal();
  GrammarProgressService._internal();

  static const String _progressPrefix = 'grammar_progress_';

  /// Returns a list of completed node IDs for a given language.
  Future<List<String>> getCompletedNodes(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_progressPrefix$langCode') ?? [];
  }

  /// Marks a node as completed for a given language.
  Future<void> completeNode(String langCode, String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList('$_progressPrefix$langCode') ?? [];
    if (!completed.contains(nodeId)) {
      completed.add(nodeId);
      await prefs.setStringList('$_progressPrefix$langCode', completed);
    }
  }

  /// Calculates the state of a node (Completed, Active, or Locked).
  /// This logic can be used when building the UI nodes.
  NodeState getNodeState(String nodeId, List<String> completedNodes, List<String> allNodeIds) {
    if (completedNodes.contains(nodeId)) {
      return NodeState.completed;
    }
    
    // Check if the previous node was completed
    final index = allNodeIds.indexOf(nodeId);
    if (index == 0) return NodeState.active; // First node is active if not completed
    
    final prevNodeId = allNodeIds[index - 1];
    if (completedNodes.contains(prevNodeId)) {
      return NodeState.active;
    }
    
    return NodeState.locked;
  }
}
