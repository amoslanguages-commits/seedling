import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/learning_path_model.dart';
import '../../services/grammar_content_service.dart';
import '../../services/grammar_progress_service.dart';
import '../../providers/course_provider.dart';
import '../../services/haptic_service.dart';
import 'lesson_screen.dart';
import 'dart:math' as math;

class PathMapScreen extends ConsumerStatefulWidget {
  const PathMapScreen({super.key});

  @override
  ConsumerState<PathMapScreen> createState() => _PathMapScreenState();
}

class _PathMapScreenState extends ConsumerState<PathMapScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pulseController;
  final Set<String> _expandedLevels = {'A1'};
  
  List<PathLevel>? _levels;
  bool _isLoading = true;
  String? _currentLangCode;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _loadData();
  }

  Future<void> _loadData() async {
    final activeCourse = ref.read(courseProvider).activeCourse;
    _currentLangCode = activeCourse?.targetLanguage.code ?? 'es';
    
    // Load Content
    final levels = await GrammarContentService.instance.loadCourse(_currentLangCode!);
    
    // Load Progress
    final completedNodes = await GrammarProgressService.instance.getCompletedNodes(_currentLangCode!);
    
    // Map State
    final allNodes = levels.expand((l) => l.nodes).toList();
    final allNodeIds = allNodes.map((n) => n.id).toList();
    
    for (var node in allNodes) {
      node.state = GrammarProgressService.instance.getNodeState(node.id, completedNodes, allNodeIds);
    }

    if (mounted) {
      setState(() {
        _levels = levels;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleLevel(String levelName) {
    setState(() {
      if (_expandedLevels.contains(levelName)) {
        _expandedLevels.remove(levelName);
      } else {
        _expandedLevels.add(levelName);
      }
    });
    HapticService.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Center(child: CircularProgressIndicator(color: SeedlingColors.seedlingGreen)),
      );
    }

    if (_levels == null || _levels!.isEmpty) {
      return Scaffold(
        backgroundColor: SeedlingColors.background,
        body: Center(
          child: Text(
            "Path data not found for this language.",
            style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Universal Path',
                      style: SeedlingTypography.heading1.copyWith(
                        color: SeedlingColors.seedlingGreen,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '121 Languages • A0 to C2',
                      style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            ..._levels!.map((level) => _buildLevelSliver(level)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelSliver(PathLevel level) {
    final bool isExpanded = _expandedLevels.contains(level.name);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => _toggleLevel(level.name),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isExpanded ? SeedlingColors.cardBackground : SeedlingColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isExpanded ? SeedlingColors.seedlingGreen.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        level.stage,
                        style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Stage ${level.stage} — ${level.title}", style: SeedlingTypography.heading3.copyWith(fontWeight: FontWeight.w800)),
                        Text(level.name, style: SeedlingTypography.body.copyWith(color: SeedlingColors.seedlingGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: SeedlingColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final node = level.nodes[index];
                  final offset = math.sin(index * 1.5) * 60.0;
                  
                  return _PathNodeWidget(
                    node: node,
                    offsetX: offset,
                    pulseAnim: _pulseController,
                    isLast: index == level.nodes.length - 1,
                    onTap: () {
                      if (node.state == NodeState.locked) {
                        HapticService.error();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Complete previous nodes first!")),
                        );
                        return;
                      }
                      HapticService.mediumImpact();
                      _showConceptSheet(context, node);
                    },
                  );
                },
                childCount: level.nodes.length,
              ),
            ),
          ),
      ],
    );
  }

  void _showConceptSheet(BuildContext context, PathNode node) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SeedlingColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => _ConceptIntroSheet(node: node, langCode: _currentLangCode!),
    ).then((_) => _loadData()); // Reload progress on return
  }
}

class _PathNodeWidget extends StatelessWidget {
  final PathNode node;
  final double offsetX;
  final Animation<double> pulseAnim;
  final bool isLast;
  final VoidCallback onTap;

  const _PathNodeWidget({
    required this.node,
    required this.offsetX,
    required this.pulseAnim,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLocked = node.state == NodeState.locked;
    final bool isActive = node.state == NodeState.active;
    final bool isCompleted = node.state == NodeState.completed;
    
    final Color nodeColor = isLocked ? SeedlingColors.textSecondary.withValues(alpha: 0.2) : node.baseColor;
    
    return SizedBox(
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!isLast)
            Positioned(
              top: 70,
              child: Container(
                width: 8,
                height: 140,
                decoration: BoxDecoration(
                  color: (isCompleted) ? node.baseColor.withValues(alpha: 0.4) : SeedlingColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            
          Transform.translate(
            offset: Offset(offsetX, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: AnimatedBuilder(
                    animation: pulseAnim,
                    builder: (context, child) {
                      final scale = isActive ? 1.0 + (pulseAnim.value * 0.08) : 1.0;
                      final shadowOpacity = isActive ? 0.3 + (pulseAnim.value * 0.3) : 0.0;
                      
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: nodeColor,
                            border: Border.all(
                              color: isCompleted ? Colors.white.withValues(alpha: 0.4) : (isLocked ? Colors.transparent : Colors.white.withValues(alpha: 0.2)),
                              width: 3,
                            ),
                            boxShadow: [
                              if (isActive)
                                BoxShadow(
                                  color: nodeColor.withValues(alpha: shadowOpacity),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              isCompleted ? Icons.check_rounded : (isLocked ? Icons.lock_rounded : node.icon),
                              color: isLocked ? SeedlingColors.textSecondary.withValues(alpha: 0.5) : Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  node.title,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isLocked ? SeedlingColors.textSecondary : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConceptIntroSheet extends StatelessWidget {
  final PathNode node;
  final String langCode;

  const _ConceptIntroSheet({required this.node, required this.langCode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: node.baseColor.withValues(alpha: 0.15),
            ),
            child: Icon(node.icon, color: node.baseColor, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            node.title,
            style: SeedlingTypography.heading2.copyWith(fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            node.subtitle,
            style: SeedlingTypography.bodyLarge.copyWith(color: SeedlingColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_alt_rounded, color: SeedlingColors.sunlight),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "This node focuses on ${node.unitTitle}.",
                    style: SeedlingTypography.body.copyWith(color: SeedlingColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: node.baseColor,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {
                HapticService.selectionClick();
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LessonScreen(
                    lesson: node.lessons.first, 
                    themeColor: node.baseColor,
                    nodeId: node.id,
                    langCode: langCode,
                    conceptExplanation: node.conceptExplanation, 
                  )),
                );
              },
              child: Text(
                'Start Lesson',
                style: SeedlingTypography.heading3.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
