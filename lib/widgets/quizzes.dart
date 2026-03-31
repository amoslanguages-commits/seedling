import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import '../core/colors.dart';
import '../core/typography.dart';
import '../models/word.dart';
import '../widgets/progress.dart';
import 'quizzes_v2.dart';
import 'seed_planting.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/target_word_display.dart';
import '../widgets/mastery_celebration.dart';
import '../widgets/tilt_card.dart';


// ================ QUIZ TYPE 1: GROW THE WORD ================
// Correct answer = plant grows visually

class GrowTheWordQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final Function(bool correct, int masteryGained) onAnswer;
  
  const GrowTheWordQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });
  
  @override
  State<GrowTheWordQuiz> createState() => _GrowTheWordQuizState();
}

class _GrowTheWordQuizState extends State<GrowTheWordQuiz> 
    with TickerProviderStateMixin {
  late AnimationController _plantGrowthController;
  late AnimationController _shakeController;
  int? _selectedIndex;
  bool _hasAnswered = false;
  double _currentGrowth = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    // Auto-play ultra high-end TTS on initial appearance
    TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode);
    
    _plantGrowthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }
  
  @override
  void dispose() {
    _plantGrowthController.dispose();
    _shakeController.dispose();
    super.dispose();
  }
  
  void _handleAnswer(int index) {
    if (_hasAnswered) return;
    
    setState(() {
      _selectedIndex = index;
      _hasAnswered = true;
    });
    
    final isCorrect = widget.options[index] == widget.word.translation;
    
    if (isCorrect) {
      _plantGrowthController.forward();
      setState(() => _currentGrowth = 1.0);
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _shakeController.forward(from: 0);
      setState(() => _currentGrowth = 0.3);
      AudioService.haptic(HapticType.wrong).ignore();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _plantGrowthController.animateTo(0.3);
      });
    }
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxHeight < 620;
        final plantFlex = isSmallScreen ? 1 : 2;
        final spacing = isSmallScreen ? 16.0 : 30.0;
        
        return Column(
          children: [
            // Growing Plant Visualization
            Expanded(
              flex: plantFlex,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _plantGrowthController, 
                  _shakeController
                ]),
                builder: (context, child) {
                  final shakeOffset = math.sin(_shakeController.value * math.pi * 8.0) * 10.0 * (1.0 - _shakeController.value);
                  
                  return Transform.translate(
                    offset: Offset(shakeOffset, 0),
                    child: CustomPaint(
                      size: Size(double.infinity, isSmallScreen ? 140 : 250),
                      painter: GrowingPlantPainter(
                        growthProgress: _currentGrowth + (_plantGrowthController.value * 0.7),
                        isWilting: _selectedIndex != null && 
                                   widget.options[_selectedIndex!] != widget.word.translation,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Word Display
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 30, 
                vertical: isSmallScreen ? 12 : 20
              ),
              decoration: BoxDecoration(
                color: SeedlingColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'What does this mean?',
                    style: SeedlingTypography.caption.copyWith(
                      fontSize: isSmallScreen ? 11 : 12,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TargetWordDisplay(
                        word: widget.word, 
                        style: SeedlingTypography.heading1.copyWith(
                          fontSize: isSmallScreen ? 28 : 36
                        )
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: SeedlingColors.seedlingGreen, size: 24),
                        onPressed: () => TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  if (widget.word.pronunciation != null) ...[
                    SizedBox(height: isSmallScreen ? 2 : 5),
                    Text(
                      widget.word.pronunciation!,
                      style: SeedlingTypography.caption.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: isSmallScreen ? 11 : 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            SizedBox(height: spacing),
            
            // Options list (Column instead of ListView to prevent internal scrolling)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = _selectedIndex == index;
                  final isCorrect = option == widget.word.translation;
                  
                  Color bgColor = SeedlingColors.cardBackground;
                  Color borderColor = SeedlingColors.morningDew.withValues(alpha: 0.3);
                  
                  if (_hasAnswered) {
                    if (isCorrect) {
                      bgColor = SeedlingColors.success.withValues(alpha: 0.2);
                      borderColor = SeedlingColors.success;
                    } else if (isSelected && !isCorrect) {
                      bgColor = SeedlingColors.error.withValues(alpha: 0.2);
                      borderColor = SeedlingColors.error;
                    }
                  } else if (isSelected) {
                    bgColor = SeedlingColors.seedlingGreen.withValues(alpha: 0.1);
                    borderColor = SeedlingColors.seedlingGreen;
                  }
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                    child: GestureDetector(
                      onTap: () => _handleAnswer(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 18, 
                          horizontal: 24
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected || (_hasAnswered && isCorrect) ? 2.0 : 1.0,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: SeedlingTypography.bodyLarge.copyWith(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  color: _hasAnswered && !isCorrect && isSelected
                                      ? SeedlingColors.error
                                      : SeedlingColors.textPrimary,
                                ),
                              ),
                            ),
                            if (_hasAnswered && isCorrect)
                              const Icon(
                                Icons.check_circle,
                                color: SeedlingColors.success,
                                size: 20,
                              ),
                            if (_hasAnswered && isSelected && !isCorrect)
                              const Icon(
                                Icons.cancel,
                                color: SeedlingColors.error,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (!isSmallScreen) const Spacer(),
          ],
        );
      },
    );
  }
}

class GrowingPlantPainter extends CustomPainter {
  final double growthProgress;
  final bool isWilting;
  
  GrowingPlantPainter({
    required this.growthProgress,
    required this.isWilting,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2.0;
    final groundY = size.height - 20.0;
    
    // Draw pot/soil
    final potPaint = Paint()
      ..color = SeedlingColors.soil
      ..style = PaintingStyle.fill;
    
    final potPath = Path()
      ..moveTo(centerX - 40.0, groundY)
      ..lineTo(centerX - 30.0, groundY + 40.0)
      ..lineTo(centerX + 30.0, groundY + 40.0)
      ..lineTo(centerX + 40.0, groundY)
      ..close();
    
    canvas.drawPath(potPath, potPaint);
    
    // Draw stem with growth
    if (growthProgress > 0) {
      final stemHeight = 120.0 * growthProgress;
      final stemPaint = Paint()
        ..color = isWilting 
            ? SeedlingColors.error.withValues(alpha: 0.7)
            : SeedlingColors.seedlingGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 * growthProgress
        ..strokeCap = StrokeCap.round;
      
      // Main stem with slight curve
      final stemPath = Path()
        ..moveTo(centerX, groundY)
        ..quadraticBezierTo(
          centerX + 10.0 * math.sin(growthProgress * math.pi),
          groundY - stemHeight / 2.0,
          centerX,
          groundY - stemHeight,
        );
      
      canvas.drawPath(stemPath, stemPaint);
      
      // Draw leaves based on growth
      final leafCount = (growthProgress * 4).floor();
      for (int i = 0; i < leafCount; i++) {
        final leafProgress = (growthProgress - (i * 0.25)) / 0.25;
        if (leafProgress > 0) {
          final leafY = groundY - (stemHeight * (0.3 + i * 0.2));
          final isLeft = i % 2 == 0;
          final angle = isLeft ? -0.5 : 0.5;
          
          _drawLeaf(
            canvas,
            centerX,
            leafY,
            angle,
            25.0 * leafProgress,
            isWilting ? SeedlingColors.error.withValues(alpha: 0.5) : SeedlingColors.freshSprout,
          );
        }
      }
      
      // Draw flower at top when fully grown
      if (growthProgress > 0.8) {
        final flowerProgress = (growthProgress - 0.8) / 0.2;
        _drawFlower(
          canvas,
          centerX,
          groundY - stemHeight,
          flowerProgress,
        );
      }
    }
    
    // Draw seed at bottom if just starting
    if (growthProgress < 0.2) {
      final seedOpacity = 1.0 - (growthProgress / 0.2);
      final seedPaint = Paint()
        ..color = SeedlingColors.soil.withValues(alpha: seedOpacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(
        Offset(centerX, groundY - 10.0),
        8.0,
        seedPaint,
      );
    }
  }
  
  void _drawLeaf(Canvas canvas, double x, double y, double angle, 
      double size, Color color) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-size/2.0, -size/3.0, 0, -size)
      ..quadraticBezierTo(size/2.0, -size/3.0, 0, 0);
    
    canvas.drawPath(path, paint);
    canvas.restore();
  }
  
  void _drawFlower(Canvas canvas, double x, double y, double progress) {
    final petalPaint = Paint()
      ..color = SeedlingColors.sunlight.withValues(alpha: progress)
      ..style = PaintingStyle.fill;
    
    final centerPaint = Paint()
      ..color = SeedlingColors.deepRoot
      ..style = PaintingStyle.fill;
    
    const petalCount = 6;
    final petalLength = 20.0 * progress;
    
    for (int i = 0; i < petalCount; i++) {
      final angle = (i / petalCount.toDouble()) * math.pi * 2.0;
      final endX = x + math.cos(angle) * petalLength;
      final endY = y + math.sin(angle) * petalLength;
      
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x + math.cos(angle + 0.3) * petalLength * 0.5,
          y + math.sin(angle + 0.3) * petalLength * 0.5,
          endX,
          endY,
        )
        ..quadraticBezierTo(
          x + math.cos(angle - 0.3) * petalLength * 0.5,
          y + math.sin(angle - 0.3) * petalLength * 0.5,
          x,
          y,
        );
      
      canvas.drawPath(path, petalPaint);
    }
    
    canvas.drawCircle(Offset(x, y), 8.0 * progress, centerPaint);
  }
  
  @override
  bool shouldRepaint(covariant GrowingPlantPainter oldDelegate) => 
      oldDelegate.growthProgress != growthProgress ||
      oldDelegate.isWilting != isWilting;
}

// ================ QUIZ TYPE 2: SWIPE TO NOURISH ================
// Swipe correct meaning into the plant

class SwipeToNourishQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final Function(bool correct, int masteryGained) onAnswer;
  
  const SwipeToNourishQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });
  
  @override
  State<SwipeToNourishQuiz> createState() => _SwipeToNourishQuizState();
}

class _SwipeToNourishQuizState extends State<SwipeToNourishQuiz> 
    with TickerProviderStateMixin {
  late AnimationController _absorbController;
  late AnimationController _rejectController;
  String? _draggedOption;
  bool _hasAnswered = false;
  
  @override
  void initState() {
    super.initState();
    
    // Auto-play ultra high-end TTS on initial appearance
    TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode);
    
    _absorbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _rejectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }
  
  @override
  void dispose() {
    _absorbController.dispose();
    _rejectController.dispose();
    super.dispose();
  }
  
  void _handleAccept(String option) {
    if (_hasAnswered) return;
    
    final isCorrect = option == widget.word.translation;
    
    setState(() {
      _hasAnswered = true;
      _draggedOption = option;
    });
    
    if (isCorrect) {
      _absorbController.forward(from: 0);
      AudioService.instance.play(SFX.correctAnswer);
      AudioService.haptic(HapticType.correct).ignore();
    } else {
      _rejectController.forward(from: 0);
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
    }
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 1 : 0);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isVerySmall = screenSize.height < 620;
    
    return Stack(
      children: [
        // Plant Container (Drop Target)
        Positioned(
          top: screenSize.height * (isVerySmall ? 0.08 : 0.15),
          left: 0,
          right: 0,
          child: DragTarget<String>(
            onWillAcceptWithDetails: (_) => !_hasAnswered,
            onAcceptWithDetails: (details) => _handleAccept(details.data),
            builder: (context, candidateData, rejectedData) {
              final isHovering = candidateData.isNotEmpty;

              return AnimatedBuilder(
                animation: Listenable.merge([_absorbController, _rejectController]),
                builder: (context, child) {
                  final hoverScale = isHovering && !_hasAnswered ? 0.05 : 0.0;
                  final scale = 1.0 + hoverScale + (_absorbController.value * 0.2) - (_rejectController.value * 0.1);
                  final shake = _rejectController.value > 0 
                      ? math.sin(_rejectController.value * math.pi * 10.0) * 10.0 
                      : 0.0;
                  
                  return Transform.translate(
                    offset: Offset(shake, 0),
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Glow indicator when hovering over plant
                          if (isHovering && !_hasAnswered)
                            Positioned(
                              top: 20,
                              child: Container(
                                width: isVerySmall ? 100 : 140,
                                height: isVerySmall ? 100 : 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SeedlingColors.water.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: SeedlingColors.water.withValues(alpha: 0.5),
                                    width: 2.0,
                                  ),
                                ),
                              ),
                            ),
                          CustomPaint(
                            size: Size(screenSize.width, isVerySmall ? 150 : 200),
                            painter: NourishPlantPainter(
                              nourishmentLevel: isHovering && !_hasAnswered 
                                  ? math.max(0.15, _absorbController.value) 
                                  : _absorbController.value,
                              isRejecting: _rejectController.value > 0,
                              isVerySmall: isVerySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // Word Display
        Positioned(
          top: screenSize.height * (isVerySmall ? 0.01 : 0.02),
          left: 20,
          right: 20,
          child: Container(
            padding: EdgeInsets.all(isVerySmall ? 12 : 20),
            decoration: BoxDecoration(
              color: SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Drag the meaning to nourish',
                  style: SeedlingTypography.caption.copyWith(
                    fontSize: isVerySmall ? 10 : 12
                  ),
                ),
                SizedBox(height: isVerySmall ? 4 : 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TargetWordDisplay(
                      word: widget.word, 
                      style: SeedlingTypography.heading1.copyWith(
                        fontSize: isVerySmall ? 26 : 32
                      )
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.volume_up_rounded, 
                        color: SeedlingColors.seedlingGreen,
                        size: isVerySmall ? 22 : 24,
                      ),
                      onPressed: () => TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Draggable Options
        Positioned(
          bottom: isVerySmall ? 20 : 100,
          left: 20,
          right: 20,
          child: Column(
            children: widget.options.map((option) {
              final isDragged = _draggedOption == option;
              final isDraggingAny = _draggedOption != null;
              
              if (isDragged && _hasAnswered) {
                return SizedBox(height: isVerySmall ? 50 : 60);
              }
              
              return Draggable<String>(
                data: option,
                onDragStarted: () {
                  setState(() => _draggedOption = option);
                },
                onDraggableCanceled: (_, __) {
                  if (!_hasAnswered) {
                    setState(() => _draggedOption = null);
                  }
                },
                onDragEnd: (details) {
                  if (!_hasAnswered && !details.wasAccepted) {
                    setState(() => _draggedOption = null);
                  }
                },
                feedback: Material(
                  color: Colors.transparent,
                  child: TiltCard(
                    maxTiltAngle: 0.20,
                    child: Transform.scale(
                      scale: 1.06,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isVerySmall ? 20 : 30,
                          vertical: isVerySmall ? 10 : 15,
                        ),
                        decoration: BoxDecoration(
                          color: SeedlingColors.seedlingGreen,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: SeedlingColors.seedlingGreen.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Text(
                          option,
                          style: SeedlingTypography.bodyLarge.copyWith(
                            color: SeedlingColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: isVerySmall ? 14 : 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.0,
                  child: _buildOptionCard(option, isVerySmall),
                ),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (isDraggingAny && !isDragged) ? 0.0 : 1.0,
                  child: _buildOptionCard(option, isVerySmall),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOptionCard(String option, bool isVerySmall) {
    return Container(
      margin: EdgeInsets.only(bottom: isVerySmall ? 8 : 12),
      padding: EdgeInsets.symmetric(
        vertical: isVerySmall ? 12 : 18, 
        horizontal: isVerySmall ? 16 : 24
      ),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drag_indicator,
            color: SeedlingColors.textSecondary,
            size: isVerySmall ? 18 : 20,
          ),
          SizedBox(width: isVerySmall ? 8 : 10),
          Text(
            option,
            style: SeedlingTypography.bodyLarge.copyWith(
              fontSize: isVerySmall ? 14 : 16
            ),
          ),
        ],
      ),
    );
  }
}

class NourishPlantPainter extends CustomPainter {
  final double nourishmentLevel;
  final bool isRejecting;
  final bool isVerySmall;
  
  NourishPlantPainter({
    required this.nourishmentLevel,
    required this.isRejecting,
    this.isVerySmall = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2.0;
    final groundY = size.height - 30.0;
    
    // Draw glow effect when nourished
    if (nourishmentLevel > 0) {
      final radius = 60.0 + (nourishmentLevel * 20.0);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            SeedlingColors.sunlight.withValues(alpha: nourishmentLevel * 0.3),
            SeedlingColors.sunlight.withValues(alpha: 0.0),
          ],
          stops: const [0.5, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, groundY - 60.0),
          radius: radius + 20.0,
        ));
      
      canvas.drawCircle(
        Offset(centerX, groundY - 60.0),
        radius + 20.0,
        glowPaint,
      );
    }
    
    // Draw plant
    final stemPaint = Paint()
      ..color = isRejecting 
          ? SeedlingColors.error 
          : SeedlingColors.seedlingGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    
    final growth = 0.7 + (nourishmentLevel * 0.3);
    final stemHeight = 100.0 * growth;
    
    // Stem
    canvas.drawLine(
      Offset(centerX, groundY),
      Offset(centerX, groundY - stemHeight),
      stemPaint,
    );
    
    // Leaves with vitality
    final leafPaint = Paint()
      ..color = isRejecting
          ? SeedlingColors.error.withValues(alpha: 0.7)
          : Color.lerp(
              SeedlingColors.freshSprout,
              SeedlingColors.sunlight,
              nourishmentLevel,
            )!
      ..style = PaintingStyle.fill;
    
    // Left leaf
    _drawVitalityLeaf(
      canvas,
      centerX,
      groundY - stemHeight * 0.5,
      -0.6,
      30.0 * growth,
      nourishmentLevel,
      leafPaint,
    );
    
    // Right leaf
    _drawVitalityLeaf(
      canvas,
      centerX,
      groundY - stemHeight * 0.7,
      0.6,
      25.0 * growth,
      nourishmentLevel,
      leafPaint,
    );
    
    // Top sprout
    if (nourishmentLevel > 0.5) {
      _drawVitalityLeaf(
        canvas,
        centerX,
        groundY - stemHeight,
        0,
        20.0 * nourishmentLevel,
        nourishmentLevel,
        leafPaint,
      );
    }
    
    // Water particles when absorbing
    if (nourishmentLevel > 0 && nourishmentLevel < 1) {
      final particlePaint = Paint()
        ..color = SeedlingColors.water.withValues(alpha: 0.6);
      
      for (int i = 0; i < 8; i++) {
        final angle = (i / 8.0) * math.pi * 2.0 + nourishmentLevel * math.pi;
        final distance = 40.0 + (nourishmentLevel * 30.0);
        final px = centerX + math.cos(angle) * distance;
        final py = groundY - 60.0 + math.sin(angle) * distance * 0.5;
        
        canvas.drawCircle(Offset(px, py), 4.0, particlePaint);
      }
    }
  }
  
  void _drawVitalityLeaf(Canvas canvas, double x, double y, double angle,
      double size, double vitality, Paint paint) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle + (vitality * 0.2 * math.sin(vitality * math.pi)));
    
    // Animate leaf size with vitality
    final animatedSize = size * (1.0 + vitality * 0.3);
    
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-animatedSize/2.0, -animatedSize/3.0, 0, -animatedSize)
      ..quadraticBezierTo(animatedSize/2.0, -animatedSize/3.0, 0, 0);
    
    canvas.drawPath(path, paint);
    
    // Draw vein
    final veinPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      const Offset(0, 0),
      Offset(0, -animatedSize * 0.8),
      veinPaint,
    );
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant NourishPlantPainter oldDelegate) =>
      oldDelegate.nourishmentLevel != nourishmentLevel ||
      oldDelegate.isRejecting != isRejecting;
}

// ================ QUIZ TYPE 3: CATCH THE RIGHT LEAF ================
// Tap the right option before it fades

class CatchTheLeafQuiz extends StatefulWidget {
  final Word word;
  final List<String> options;
  final Function(bool correct, int masteryGained) onAnswer;
  
  const CatchTheLeafQuiz({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswer,
  });
  
  @override
  State<CatchTheLeafQuiz> createState() => _CatchTheLeafQuizState();
}

class _CatchTheLeafQuizState extends State<CatchTheLeafQuiz> 
    with TickerProviderStateMixin {
  late List<AnimationController> _floatControllers;
  late List<Offset> _positions;
  late List<Offset> _velocities;
  bool _hasAnswered = false;
  int? _caughtIndex;
  Timer? _gameTimer;
  
  @override
  void initState() {
    super.initState();
    
    // Auto-play ultra high-end TTS on initial appearance
    TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode);
    
    _floatControllers = List.generate(
      widget.options.length,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 2000 + (index * 500)),
      )..repeat(),
    );
    
    // Fading and timer logic removed for a more relaxed experience.
    
    // Random positions and velocities
    final random = math.Random();
    _positions = List.generate(
      widget.options.length,
      (index) => Offset(
        0.2 + (random.nextDouble() * 0.6),
        0.3 + (random.nextDouble() * 0.4),
      ),
    );
    
    _velocities = List.generate(
      widget.options.length,
      (index) => Offset(
        (random.nextDouble() - 0.5) * 0.002,
        (random.nextDouble() - 0.5) * 0.002,
      ),
    );
    
    // Game loop for movement only
    _gameTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          // Update positions
          for (int i = 0; i < _positions.length; i++) {
            _positions[i] = Offset(
              (_positions[i].dx + _velocities[i].dx).clamp(0.1, 0.9),
              (_positions[i].dy + _velocities[i].dy).clamp(0.2, 0.8),
            );
            
            // Bounce off edges
            if (_positions[i].dx <= 0.1 || _positions[i].dx >= 0.9) {
              _velocities[i] = Offset(-_velocities[i].dx, _velocities[i].dy);
            }
            if (_positions[i].dy <= 0.2 || _positions[i].dy >= 0.8) {
              _velocities[i] = Offset(_velocities[i].dx, -_velocities[i].dy);
            }
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    for (var controller in _floatControllers) {
      controller.dispose();
    }
    _gameTimer?.cancel();
    super.dispose();
  }
  
  void _handleCatch(int index) {
    if (_hasAnswered) return;
    
    _gameTimer?.cancel();
    
    final isCorrect = widget.options[index] == widget.word.translation;
    
    setState(() {
      _hasAnswered = true;
      _caughtIndex = index;
    });
    
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) widget.onAnswer(isCorrect, isCorrect ? 2 : 0);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isVerySmall = size.height < 620;
    
    return Column(
      children: [
        SizedBox(height: isVerySmall ? 10 : 20),
        
        // Word Display
        Container(
          padding: EdgeInsets.all(isVerySmall ? 12 : 20),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                'Catch the meaning!',
                style: SeedlingTypography.caption.copyWith(
                  fontSize: isVerySmall ? 10 : 12,
                ),
              ),
              SizedBox(height: isVerySmall ? 4 : 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TargetWordDisplay(
                    word: widget.word, 
                    style: SeedlingTypography.heading1.copyWith(
                      fontSize: isVerySmall ? 28 : 36
                    )
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.volume_up_rounded, 
                      color: SeedlingColors.seedlingGreen,
                      size: isVerySmall ? 22 : 24,
                    ),
                    onPressed: () => TtsService.instance.speak(widget.word.ttsWord, widget.word.targetLanguageCode),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        SizedBox(height: isVerySmall ? 10 : 20),
        
        // Game Area
        Expanded(
          child: Stack(
            children: [
              // Background wind effect
              CustomPaint(
                size: Size(size.width, size.height * 0.6),
                painter: WindEffectPainter(
                  progress: _floatControllers[0].value,
                ),
              ),
              
              // Floating Leaves
              ...widget.options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final position = _positions[index];
                
                return AnimatedBuilder(
                  animation: _floatControllers[index],
                  builder: (context, child) {
                    final floatOffset = math.sin(
                      _floatControllers[index].value * math.pi * 2.0,
                    ) * 10.0;
                    
                    const opacity = 1.0;
                    
                    final isCaught = _caughtIndex == index;
                    final isCorrect = option == widget.word.translation;
                    
                    Color leafColor = SeedlingColors.freshSprout;
                    if (_hasAnswered) {
                      if (isCorrect) {
                        leafColor = SeedlingColors.success;
                      } else if (isCaught && !isCorrect) {
                        leafColor = SeedlingColors.error;
                      }
                    }
                    
                    return Positioned(
                      left: position.dx * size.width - (isVerySmall ? 50.0 : 60.0),
                      top: position.dy * size.height * 0.5 + floatOffset,
                      child: GestureDetector(
                        onTap: () => _handleCatch(index),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isCaught ? 0.0 : opacity,
                          child: Transform.scale(
                            scale: isCaught ? 1.5 : 1.0,
                            child: SizedBox(
                              width: isVerySmall ? 100 : 120,
                              height: isVerySmall ? 66 : 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Transform.rotate(
                                    angle: _floatControllers[index].value * 0.2,
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        size: Size(isVerySmall ? 100 : 120, isVerySmall ? 66 : 80),
                                        painter: FloatingWordLeafPainter(
                                          color: leafColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    option,
                                    textAlign: TextAlign.center,
                                    style: SeedlingTypography.bodyLarge.copyWith(
                                      color: SeedlingColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isVerySmall ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class WindEffectPainter extends CustomPainter {
  final double progress;
  
  WindEffectPainter({required this.progress});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SeedlingColors.morningDew.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    for (int i = 0; i < 3; i++) {
      final y = size.height * (0.2 + i * 0.3);
      final path = Path();
      
      path.moveTo(0, y);
      for (double x = 0.0; x < size.width; x += 50.0) {
        path.quadraticBezierTo(
          x + 25.0,
          y + math.sin((x / size.width + progress) * math.pi * 2.0) * 10.0,
          x + 50.0,
          y,
        );
      }
      
      canvas.drawPath(path, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant WindEffectPainter oldDelegate) => true;
}

class FloatingWordLeafPainter extends CustomPainter {
  final Color color;
  
  FloatingWordLeafPainter({
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2.0, size.height / 2.0);
    
    // Draw leaf shape
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(0, -size.height / 2.0)
      ..quadraticBezierTo(
        -size.width / 2.0, -size.height / 4.0,
        -size.width / 3.0, 0,
      )
      ..quadraticBezierTo(
        -size.width / 4.0, size.height / 4.0,
        0, size.height / 2.0,
      )
      ..quadraticBezierTo(
        size.width / 4.0, size.height / 4.0,
        size.width / 3.0, 0,
      )
      ..quadraticBezierTo(
        size.width / 2.0, -size.height / 4.0,
        0, -size.height / 2.0,
      );
    
    // Hardware-accelerated Shadow
    canvas.save();
    canvas.translate(4, 4);
    canvas.drawShadow(path, SeedlingColors.deepRoot.withValues(alpha: 0.35), 6.0, false);
    canvas.restore();
    
    // Leaf
    canvas.drawPath(path, paint);
    
    // Vein
    final veinPaint = Paint()
      ..color = SeedlingColors.deepRoot.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawLine(
      Offset(0, -size.height / 2.0 + 10.0),
      Offset(0, size.height / 2.0 - 10.0),
      veinPaint,
    );
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant FloatingWordLeafPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ================ QUIZ TYPE 4: BUILD THE TREE ================
// Connect words into meaning clusters

class BuildTheTreeQuiz extends StatefulWidget {
  final List<Word> words;
  final Function(int correctConnections, int totalConnections) onComplete;
  
  const BuildTheTreeQuiz({
    super.key,
    required this.words,
    required this.onComplete,
  });
  
  @override
  State<BuildTheTreeQuiz> createState() => _BuildTheTreeQuizState();
}

class _BuildTheTreeQuizState extends State<BuildTheTreeQuiz> 
    with TickerProviderStateMixin {
  late List<Word> _shuffledWords;
  late List<String> _shuffledTranslations;
  final List<int> _connections = [];
  int? _selectedWordIndex;
  int _correctConnections = 0;
  late AnimationController _growController;
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _shuffledWords = List.from(widget.words)..shuffle();
    _shuffledTranslations = _shuffledWords.map((w) => w.translation).toList()..shuffle();
    
    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _growController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _handleWordTap(int index) {
    setState(() {
      // Always play TTS if tapping a translation's target word node (left side)
      if (index < _shuffledWords.length) {
        final w = _shuffledWords[index];
        TtsService.instance.speak(w.word, w.targetLanguageCode);
      }

      if (_selectedWordIndex == null) {
        _selectedWordIndex = index;
      } else if (_selectedWordIndex == index) {
        _selectedWordIndex = null;
      } else {
        // Try to connect (if one is from left and one from right side)
        final isLeft1 = _selectedWordIndex! < _shuffledWords.length;
        final isLeft2 = index < _shuffledWords.length;
        
        if (isLeft1 != isLeft2) {
          final wordIdx = isLeft1 ? _selectedWordIndex! : index;
          final transIdx = isLeft1 ? index - _shuffledWords.length : _selectedWordIndex! - _shuffledWords.length;
          _attemptConnection(wordIdx, transIdx);
        }
        _selectedWordIndex = null;
      }
    });
  }
  
  void _attemptConnection(int wordIndex, int translationIndex) {
    final word = _shuffledWords[wordIndex];
    final translation = _shuffledTranslations[translationIndex];
    
    if (word.translation == translation) {
      // Check if already connected
      if (_connections.contains(wordIndex) || _connections.contains(translationIndex + _shuffledWords.length)) {
        return;
      }

      setState(() {
        _connections.add(wordIndex);
        _connections.add(translationIndex + _shuffledWords.length);
        _correctConnections++;
      });
      
      _growController.forward(from: 0);
      
      if (_correctConnections >= widget.words.length) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) widget.onComplete(_correctConnections, widget.words.length);
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SeedlingColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                'Build the Knowledge Tree',
                style: SeedlingTypography.heading2,
              ),
              const SizedBox(height: 5),
              Text(
                'Connect words to their meanings',
                style: SeedlingTypography.caption,
              ),
              const SizedBox(height: 15),
              StemProgressBar(
                progress: _correctConnections / widget.words.length,
                height: 8,
              ),
            ],
          ),
        ),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxHeight < 500;
              final nodeCount = _shuffledWords.length;
              final spacing = (constraints.maxHeight - 120) / (nodeCount - 1).clamp(1, 10);
              final itemSpacing = spacing.clamp(50.0, 110.0);
              final startTop = isSmallScreen ? 20.0 : 40.0;

              return AnimatedBuilder(
                animation: Listenable.merge([_growController, _pulseController]),
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: KnowledgeTreePainter(
                      words: _shuffledWords.map((w) => w.word).toList(),
                      translations: _shuffledTranslations,
                      connections: _connections,
                      selectedIndex: _selectedWordIndex,
                      growthProgress: _growController.value,
                      pulseValue: _pulseController.value,
                      isSmallScreen: isSmallScreen,
                      itemSpacing: itemSpacing,
                      startTop: startTop,
                    ),
                    child: Stack(
                      children: [
                        // Word nodes (left side)
                        ..._shuffledWords.asMap().entries.map((entry) {
                          final index = entry.key;
                          final word = entry.value;
                          final isConnected = _connections.contains(index);
                          final isSelected = _selectedWordIndex == index;
                          
                          return Positioned(
                            left: isSmallScreen ? 15 : 30,
                            top: startTop + (index * itemSpacing),
                            child: GestureDetector(
                              onTap: () => _handleWordTap(index),
                              child: _buildTreeNode(
                                word.word,
                                isConnected,
                                isSelected,
                                true,
                                isSmallScreen,
                              ),
                            ),
                          );
                        }),
                        
                        // Translation nodes (right side)
                        ..._shuffledTranslations.asMap().entries.map((entry) {
                          final index = entry.key + _shuffledWords.length;
                          final translation = entry.value;
                          final isConnected = _connections.contains(index);
                          final isSelected = _selectedWordIndex == index;
                          
                          return Positioned(
                            right: isSmallScreen ? 15 : 30,
                            top: startTop + ((index - _shuffledWords.length) * itemSpacing),
                            child: GestureDetector(
                              onTap: () => _handleWordTap(index),
                              child: _buildTreeNode(
                                translation,
                                isConnected,
                                isSelected,
                                false,
                                isSmallScreen,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              );
            }
          ),
        ),
      ],
    );
  }
  
  Widget _buildTreeNode(
    String text,
    bool isConnected,
    bool isSelected,
    bool isLeft,
    bool isSmallScreen,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 20, 
        vertical: isSmallScreen ? 8 : 12
      ),
      decoration: BoxDecoration(
        color: isConnected
            ? SeedlingColors.success.withValues(alpha: 0.2)
            : isSelected
                ? SeedlingColors.seedlingGreen.withValues(alpha: 0.2)
                : SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 20),
        border: Border.all(
          color: isConnected
              ? SeedlingColors.success
              : isSelected
                  ? SeedlingColors.seedlingGreen
                  : SeedlingColors.morningDew.withValues(alpha: 0.3),
          width: isConnected || isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: SeedlingColors.seedlingGreen.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: SeedlingTypography.body.copyWith(
          fontSize: isSmallScreen ? 13 : 15,
          fontWeight: isConnected || isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isConnected
              ? SeedlingColors.success
              : isSelected
                  ? SeedlingColors.seedlingGreen
                  : SeedlingColors.textPrimary,
        ),
      ),
    );
  }
}

class KnowledgeTreePainter extends CustomPainter {
  final List<String> words;
  final List<String> translations;
  final List<int> connections;
  final int? selectedIndex;
  final double growthProgress;
  final double pulseValue;
  final bool isSmallScreen;
  final double itemSpacing;
  final double startTop;
  
  KnowledgeTreePainter({
    required this.words,
    required this.translations,
    required this.connections,
    required this.selectedIndex,
    required this.growthProgress,
    required this.pulseValue,
    this.isSmallScreen = false,
    this.itemSpacing = 100.0,
    this.startTop = 80.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final nodeCenterOffset = isSmallScreen ? 15.0 : 20.0;

    // Draw connections
    for (int i = 0; i < connections.length; i += 2) {
      final wordIndex = connections[i];
      final transIndex = connections[i + 1];
      
      final startX = (isSmallScreen ? 15.0 : 30.0) + 60.0; 
      final startY = startTop + (wordIndex * itemSpacing) + nodeCenterOffset;
      final endX = size.width - ((isSmallScreen ? 15.0 : 30.0) + 60.0);
      final endY = startTop + ((transIndex - words.length) * itemSpacing) + nodeCenterOffset;
      
      // Animate growth
      final progress = (growthProgress + (i / connections.length) * 0.3).clamp(0.0, 1.0);
      final currentEndX = startX + (endX - startX) * progress;
      final currentEndY = startY + (endY - startY) * progress;
      
      final paint = Paint()
        ..color = SeedlingColors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      
      // Draw root-like connection
      final path = Path()
        ..moveTo(startX, startY)
        ..cubicTo(
          startX + 50.0, startY,
          currentEndX - 50.0, currentEndY,
          currentEndX, currentEndY,
        );
      
      canvas.drawPath(path, paint);
      
      // Draw glow at connection point
      if (progress >= 1.0) {
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              SeedlingColors.success.withValues(alpha: 0.3 * pulseValue),
              SeedlingColors.success.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(
            center: Offset(currentEndX, currentEndY),
            radius: 20.0,
          ));
        
        canvas.drawCircle(
          Offset(currentEndX, currentEndY),
          20.0,
          glowPaint,
        );
      }
    }
    
    // Draw selection preview line
    if (selectedIndex != null) {
      final isWordSide = selectedIndex! < words.length;
      final offset = (isSmallScreen ? 15.0 : 30.0) + 60.0;
      final startX = isWordSide ? offset : size.width - offset;
      final startY = startTop + ((isWordSide ? selectedIndex! : selectedIndex! - words.length) * itemSpacing) + nodeCenterOffset;
      
      final paint = Paint()
        ..color = SeedlingColors.seedlingGreen.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      
      // Dashed line effect
      const totalDashes = 10;
      
      for (int i = 0; i < totalDashes; i++) {
        final t = i / totalDashes;
        final nextT = (i + 0.5) / totalDashes;
        
        final x1 = startX + (isWordSide ? 1 : -1) * t * 100;
        final y1 = startY;
        final x2 = startX + (isWordSide ? 1 : -1) * nextT * 100;
        final y2 = startY;
        
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant KnowledgeTreePainter oldDelegate) =>
      oldDelegate.connections != connections ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.growthProgress != growthProgress ||
      oldDelegate.pulseValue != pulseValue;
}

// ================================================================
// ADAPTIVE LEARNING ENGINE
// ================================================================
// Design principles:
//  • All 8 quiz types rotate using a Fisher-Yates shuffled pool.
//  • NEW words appear up to 4×: they're re-inserted at increasing
//    intervals (Leitner-within-session). Wrong answers bring any
//    word back sooner for immediate reinforcement.
//  • Planting moment is adaptive: a ReadinessScore (0-100) is
//    calculated per-turn from accuracy, streak, difficulty, and
//    words-completed. Word is introduced when score >= 60.
//  • Multi-word milestone quizzes (BuildTheTree, RootNetwork) fire
//    every 6th quiz turn, consuming up to 4 words at once.
// ================================================================

// ---------- Data model ----------

enum _CardKind {
  reviewWord,   // SRS-due word (appears once unless wrong)
  newWordRound, // New word's scheduled appearance (up to 4 total)
}

class _SessionCard {
  final Word word;
  final _CardKind kind;
  int step; // for newWordRound: 0-3; for reviewWord: always 0

  _SessionCard({required this.word, required this.kind, this.step = 0});
}

// ---------- Adaptive Queue ----------

class _AdaptiveQueue {
  final List<_SessionCard> _queue = [];
  final math.Random _rng = math.Random();

  int totalAnswered = 0;
  int totalCorrect  = 0;
  int streak        = 0; // consecutive correct answers
  int reviewDone    = 0; // number of review words completed

  // All quiz types available for the randomized pool. 
  // Most adapt to vocabulary size (3-4 options).
  static const _allQuizTypes = [
    'growWord', 'swipeNourish', 'catchLeaf', 'buildTree',
    'deepRoot', 'bloomOrWilt', 'seedSort', 'rootNetwork',
    'picturePick', 'whatWordIsThis', 'gardenSort', 'engraveRoot',
  ];
  // Milestone (multi-word) quizzes — fire every 6th turn.
  static const _milestoneTypes = {'buildTree', 'rootNetwork'};

  List<String> _quizPool = [];
  int _quizTurnCount = 0;

  void _refillPool() {
    _quizPool = List.of(_allQuizTypes)..shuffle(_rng);
  }

  /// The quiz type to use for the CURRENT queue head.
  String nextQuizType() {
    _quizTurnCount++;
    if (_quizTurnCount % 6 == 0) {
      // Milestone turn — pick a multi-word quiz randomly.
      return _milestoneTypes.elementAt(_rng.nextInt(_milestoneTypes.length));
    }
    // Regular turn — pull from shuffled pool (skip milestone types).
    while (true) {
      if (_quizPool.isEmpty) _refillPool();
      final t = _quizPool.removeLast();
      if (!_milestoneTypes.contains(t)) return t;
      // Put milestone back and try again.
      _quizPool.insert(0, t);
    }
  }

  // ── Queue management ─────────────────────────────────────────────

  void seedReviewWords(List<Word> words) {
    for (final w in words) {
      _queue.add(_SessionCard(word: w, kind: _CardKind.reviewWord));
    }
    _queue.shuffle(_rng);
    _refillPool();
  }

  /// Schedule the new word at step 0. True Pimsleur spacing happens progressively
  /// as the user answers correctly in `advance`.
  void injectNewWord(Word word) {
    // Insert immediately at a close position (e.g. index 1 or 2).
    // The very first injection is step 0.
    final pos = math.min(1, _queue.length);
    _queue.insert(pos, _SessionCard(word: word, kind: _CardKind.newWordRound, step: 0));
  }

  bool get isEmpty => _queue.isEmpty;

  _SessionCard? get current => _queue.isEmpty ? null : _queue.first;

  /// Call after answering the current card.
  void advance({required bool correct, required int timeTakenMs}) {
    if (_queue.isEmpty) return;
    final card = _queue.removeAt(0);

    totalAnswered++;
    if (correct) {
      totalCorrect++;
      streak++;
    } else {
      streak = 0;
    }

    final isSlow = timeTakenMs > 13000; // 12s + roughly 1s for animation delays

    if (card.kind == _CardKind.newWordRound) {
      // New-word progressive intervals
      if (correct) {
        if (!isSlow && card.step >= 3) {
          // All 4 passes done rapidly — graduated!
          return;
        }
        
        // Anti-Cheating: Speed Decay Penalty. If slow, they don't jump a full Pimsleur step.
        final nextStep = isSlow ? card.step : card.step + 1;
        const gapsForCorrect = [2, 5, 9, 14];
        
        // If slow, shrink the gap heavily so they re-test soon.
        final gap = isSlow ? math.min(2, _queue.length) : math.min(gapsForCorrect[nextStep], _queue.length);
        
        _queue.insert(gap, _SessionCard(word: card.word, kind: _CardKind.newWordRound, step: nextStep));
      } else {
        // Wrong answer: keep same step, narrow gap
        final gap = math.min(2, _queue.length);
        _queue.insert(gap, _SessionCard(word: card.word, kind: _CardKind.newWordRound, step: card.step));
      }
    } else {
      // Review word logic (Leitner)
      if (!correct) {
        // Fail-State Regression: If you miss a review word, you have to re-learn it
        // by progressing through all 4 steps like a new word!
        final gap = math.min(1, _queue.length);
        _queue.insert(gap, _SessionCard(word: card.word, kind: _CardKind.newWordRound, step: 0));
      } else {
        if (isSlow) {
          // Speed penalty on review words: force them to see it one more time.
          final gap = math.min(5, _queue.length);
          _queue.insert(gap, _SessionCard(word: card.word, kind: _CardKind.reviewWord));
        } else {
          reviewDone++;
        }
      }
    }
  }

  /// Advance by N cards (used after multi-word milestone quizzes).
  void advanceMultiple(int count, {required int correctCount}) {
    for (int i = 0; i < count && _queue.isNotEmpty; i++) {
      final isCorrect = i < correctCount;
      // Multi-word quizzes consume review words, not new-word rounds.
      final card = _queue.removeAt(0);
      totalAnswered++;
      if (isCorrect) {
        totalCorrect++;
        streak++;
        if (card.kind == _CardKind.reviewWord) reviewDone++;
      } else {
        streak = 0;
        // Re-insert wrong ones at front+2.
        final gap = math.min(2, _queue.length);
        _queue.insert(gap, _SessionCard(word: card.word, kind: card.kind));
      }
    }
  }

  // ── ReadinessScore (0-100) ───────────────────────────────────────
  // Determines how ready the user is for a new word to be planted.

  double readinessScore(Word candidateWord) {
    double score = 0;

    // Session accuracy
    if (totalAnswered > 0) {
      final acc = totalCorrect / totalAnswered;
      if (acc >= 0.7) {
        score += 25;
      } else if (acc >= 0.5) {
        score += 12;
      }
    }

    // Current streak
    if (streak >= 3) {
      score += 20;
    } else if (streak >= 1) {
      score += 8;
    }

    // Review words completed (need at least 2 before introducing new)
    if (reviewDone >= 4) {
      score += 15;
    } else if (reviewDone >= 2) {
      score += 10;
    } else {
      score -= 20; // Too early — haven't warmed up yet.
    }

    // Word difficulty vs user's average mastery
    // Low difficulty relative to mastery → easier introduction.
    final difficultyFactor = 1.0 - (candidateWord.difficulty / 5.0);
    score += difficultyFactor * 15;

    // Small random noise to avoid mechanical predictability.
    score += (_rng.nextDouble() - 0.5) * 10;

    return score.clamp(0, 100);
  }
}

// ---------- QuizManager Widget ----------

class QuizManager extends StatefulWidget {
  final List<Word> words;
  final List<Word> initialNewWords;
  final Word? newWordToPlant;
  final Future<void> Function(Word)? onWordPlanted;
  final Function(int totalCorrect, int totalQuestions) onProgressUpdate;
  final VoidCallback onSessionComplete;

  const QuizManager({
    super.key,
    required this.words,
    this.initialNewWords = const [],
    this.newWordToPlant,
    this.onWordPlanted,
    required this.onProgressUpdate,
    required this.onSessionComplete,
  });

  @override
  State<QuizManager> createState() => _QuizManagerState();
}

class _QuizManagerState extends State<QuizManager> {
  late final _AdaptiveQueue _queue;
  String _currentQuizType = 'deepRoot';

  bool _newWordInjected  = false;    // has the new word been added to queue?
  bool _newWordPlanted   = false;    // has the SeedPlantingScreen been shown?
  bool _showPlanting     = false;    // triggers SeedPlantingScreen overlay
  
  late final Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _queue = _AdaptiveQueue();
    _queue.seedReviewWords(widget.words);
    
    // Inject any words that were just planted before the session started
    // so they receive the 4-repetition "new word" treatment immediately.
    for (final initialWord in widget.initialNewWords) {
      _queue.injectNewWord(initialWord);
    }
    
    _currentQuizType = _determineQuizType();
    // Play session-start whoosh + start ambient garden layer
    AudioService.instance.play(SFX.quizStart);
    AudioService.haptic(HapticType.tap);
    AudioService.instance.startAmbient();
  }

  String _determineQuizType() {
    if (_queue.isEmpty) return 'deepRoot';
    final card = _queue.current!;

    // PROGRESSIVE DIFFICULTY FOR NEW WORDS
    if (card.kind == _CardKind.newWordRound) {
      switch (card.step) {
        case 0:
          // 1st appearance: Simple visual matching
          return ['growWord', 'bloomOrWilt', 'picturePick'][math.Random().nextInt(3)];
        case 1:
          // 2nd appearance: Passive sorting or translation
          return ['swipeNourish', 'seedSort', 'whatWordIsThis', 'gardenSort'][math.Random().nextInt(4)];
        case 2:
          // 3rd appearance: Active recall with aid
          return 'catchLeaf';
        case 3:
        default:
          // 4th appearance (Mastery): Absolute active recall / hard typing
          return 'engraveRoot';
      }
    }
    
    // For review words, use the normal queue's randomized type (excluding milestones here, 
    // milestones are handled separately if we want, but letting the queue decide is fine).
    return _queue.nextQuizType();
  }

  // ── Readiness check (called after each answer) ────────────────────

  void _maybeInjectNewWord() {
    if (_newWordInjected || widget.newWordToPlant == null) return;
    final score = _queue.readinessScore(widget.newWordToPlant!);
    if (score >= 60) {
      _newWordInjected = true;
      // Show planting screen first, then inject the word into the queue.
      setState(() => _showPlanting = true);
    }
  }

  void _onPlantingComplete() {
    AudioService.instance.play(SFX.wordPlanted);
    AudioService.haptic(HapticType.plant);
    setState(() {
      _showPlanting  = false;
      _newWordPlanted = true;
      _queue.injectNewWord(widget.newWordToPlant!);
    });
    widget.onProgressUpdate(_queue.totalCorrect, _queue.totalAnswered);
    _checkDone();
  }

  void _checkDone() {
    final queueEmpty = _queue.isEmpty;
    final plantingDone = widget.newWordToPlant == null ||
        (_newWordInjected && _newWordPlanted);
    if (queueEmpty && plantingDone) {
      AudioService.instance.stopAmbient();
      AudioService.instance.play(SFX.sessionComplete);
      AudioService.haptic(HapticType.sessionComplete);
      widget.onSessionComplete();
    } else if (queueEmpty && !_newWordInjected && widget.newWordToPlant != null) {
      // Queue empty but we never reached readiness — force plant now.
      setState(() {
        _newWordInjected = true;
        _showPlanting = true;
      });
    }
  }

  void _handleAnswer(bool correct, int mastery) {
    if (!mounted) return;
    
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    _stopwatch.stop();
    _stopwatch.reset();
    
    // — FIRE SFX + HAPTIC IMMEDIATELY — (before setState for zero-latency)
    if (correct) {
      final streak = _queue.streak;
      if (streak > 0 && streak % 3 == 0) {
        // Streak milestone: bigger fanfare
        AudioService.instance.play(SFX.streakBonus);
        AudioService.haptic(HapticType.levelUp);
      } else {
        // Escalating correct chord based on streak tier (pitch shifts up each tier)
        AudioService.instance.playCorrect(streak: streak);
        AudioService.haptic(HapticType.correct);
      }

      // 🌳 Mastery Celebration: fire confetti when EngraveRoot is completed
      if (_currentQuizType == 'engraveRoot' && mastery >= 1) {
        final word = _queue.current?.word;
        if (word != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              MasteryCelebration.show(context, word.ttsWord);
            }
          });
        }
      }
    } else {
      AudioService.instance.play(SFX.wrongAnswer);
      AudioService.haptic(HapticType.wrong).ignore();
      AudioService.haptic(HapticType.wrong);
    }

    setState(() {
      _queue.advance(correct: correct, timeTakenMs: elapsedMs);
      widget.onProgressUpdate(_queue.totalCorrect, _queue.totalAnswered);
      _maybeInjectNewWord();
      if (!_showPlanting) {
        _currentQuizType = _determineQuizType();
      }
      _checkDone();
      _stopwatch.start();
    });
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Planting overlay ──────────────────────────────────────────
    if (_showPlanting && widget.newWordToPlant != null) {
      return SeedPlantingScreen(
        words: [widget.newWordToPlant!],
        initialBatchSize: 1,
        headerLabel: 'Plant Something New 🌱',
        isEmbedded: true,
        onWordPlanted: widget.onWordPlanted,
        onPlantingComplete: _onPlantingComplete,
      );
    }

    // ── Session complete spinner (briefly shown) ──────────────────
    if (_queue.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final card    = _queue.current!;
    final current = card.word;
    final options = _generateOptions(current);

    // ── Pick quiz widget ──────────────────────────────────────────
    switch (_currentQuizType) {

      // ── Original: Grow The Word ─────────────────────────────────
      case 'growWord':
        return GrowTheWordQuiz(
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── Original: Swipe To Nourish ──────────────────────────────
      case 'swipeNourish':
        return SwipeToNourishQuiz(
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── Original: Catch The Leaf ────────────────────────────────
      case 'catchLeaf':
        return CatchTheLeafQuiz(
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── Original: Build The Tree (milestone) ────────────────────
      case 'buildTree':
        {
          final batchSize = math.min(4, _queue._queue.length + 1);
          final batchWords = <Word>[current];
          for (var i = 0; i < _queue._queue.length && batchWords.length < batchSize; i++) {
            final w = _queue._queue[i].word;
            if (!batchWords.any((x) => x.id == w.id)) batchWords.add(w);
          }
          return BuildTheTreeQuiz(
            words: batchWords,
            onComplete: (correct, total) {
              _queue.advanceMultiple(total, correctCount: correct);
              widget.onProgressUpdate(_queue.totalCorrect, _queue.totalAnswered);
              _maybeInjectNewWord();
              if (!_showPlanting) {
                setState(() {
                  _currentQuizType = _determineQuizType();
                });
              }
              _checkDone();
            },
          );
        }

      // ── V2: Deep Root ───────────────────────────────────────────
      case 'deepRoot':
        return DeepRootQuiz(
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );

      // ── V2: Engrave Root (Anti-Cheating Mastery) ────────────────
      case 'engraveRoot':
        return EngraveRootQuiz(
          word: current,
          onAnswer: _handleAnswer,
        );

      // ── V2 Image: Picture Pick ──────────────────────────────────
      case 'picturePick':
        return PicturePickQuiz(
          word: current,
          options: _getObjOptions(current),
          onAnswer: _handleAnswer,
        );

      // ── V2 Image: What Word Is This? ────────────────────────────
      case 'whatWordIsThis':
        return WhatWordIsThisQuiz(
          word: current,
          options: options, // uses the same string distractors
          onAnswer: _handleAnswer,
        );

      // ── V2 Image: Garden Sort ───────────────────────────────────
      case 'gardenSort':
        {
          final decoyStr = _getDecoy(current);
          final decoyWord = _getWordFromTranslation(decoyStr);
          return GardenSortQuiz(
            word: current,
            decoyWord: decoyWord ?? current, // Fallback to current if error
            onAnswer: _handleAnswer,
          );
        }

      // ── V2: Bloom Or Wilt ───────────────────────────────────────
      case 'bloomOrWilt':
        {
          final showCorrect = math.Random().nextBool();
          final decoy = _getDecoy(current);
          return BloomOrWiltQuiz(
            word: current,
            shownTranslation: showCorrect ? current.translation : decoy,
            isCorrectPair: showCorrect,
            onAnswer: _handleAnswer,
          );
        }

      // ── V2: Seed Sort ───────────────────────────────────────────
      case 'seedSort':
        {
          final potOptions = [current.translation, _getDecoy(current)]
            ..shuffle();
          return SeedSortQuiz(
            word: current,
            potOptions: potOptions,
            onAnswer: _handleAnswer,
          );
        }

      // ── V2: Root Network (milestone) ────────────────────────────
      case 'rootNetwork':
        {
          final remaining = <Word>[current];
          for (var i = 0; i < _queue._queue.length && remaining.length < 4; i++) {
            final w = _queue._queue[i].word;
            if (!remaining.any((x) => x.id == w.id)) remaining.add(w);
          }
          return RootNetworkQuiz(
            words: remaining,
            onComplete: (correct, total) {
              _queue.advanceMultiple(total, correctCount: correct);
              widget.onProgressUpdate(_queue.totalCorrect, _queue.totalAnswered);
              _maybeInjectNewWord();
              if (!_showPlanting) {
                setState(() {
                  _currentQuizType = _queue.nextQuizType();
                });
              }
              _checkDone();
            },
          );
        }

      default:
        return DeepRootQuiz(
          word: current,
          options: options,
          onAnswer: _handleAnswer,
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var v0 = List<int>.generate(b.length + 1, (i) => i);
    var v1 = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        var cost = (a[i].toLowerCase() == b[j].toLowerCase()) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (var j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  List<Word> _getAllSessionWords() {
    final list = List<Word>.from(widget.words);
    list.addAll(widget.initialNewWords);
    if (widget.newWordToPlant != null) list.add(widget.newWordToPlant!);
    return list;
  }

  List<String> _generateOptions(Word correctWord) {
    final rng = math.Random();
    
    // Contextual Distractors: Favor words with similar length/spelling (anticheating)
    final allSessionWords = _getAllSessionWords();
    final validPool = allSessionWords
        .where((w) => w.id != correctWord.id)
        .map((w) => w.translation)
        .toSet() // Remove duplicates if any
        .toList();
        
    // Sort by Levenshtein distance to find "difficult" distractors
    validPool.sort((a, b) => 
      _levenshtein(correctWord.translation, a).compareTo(
      _levenshtein(correctWord.translation, b))
    );
    
    // Shuffle the best candidates to avoid predictable patterns
    final candidates = validPool.take(6).toList()..shuffle(rng);
    
    // Take up to 3 distractors for 3-4 options total
    final wrong = candidates.take(3).toList();
    return [correctWord.translation, ...wrong]..shuffle(rng);
  }

  String _getDecoy(Word word) {
    final allSessionWords = _getAllSessionWords();
    final others = allSessionWords.where((w) => w.id != word.id).toList();
    if (others.isEmpty) return '—';
    
    final validPool = others.map((w) => w.translation).toSet().toList();
    // Sort by similarity for a better "decoy" challenge
    validPool.sort((a, b) => 
      _levenshtein(word.translation, a).compareTo(
      _levenshtein(word.translation, b))
    );
    
    // Pick from top 3 closest ones
    return validPool.take(3).toList()[math.Random().nextInt(math.min(3, validPool.length))];
  }

  Word? _getWordFromTranslation(String translation) {
    if (translation == '—') return null;
    final all = _getAllSessionWords();
    try {
      return all.firstWhere((w) => w.translation == translation);
    } catch (_) {
      return null;
    }
  }

  List<Word> _getObjOptions(Word correctWord) {
    final rng = math.Random();
    final allSessionWords = _getAllSessionWords();
    final validPool = allSessionWords
        .where((w) => w.id != correctWord.id)
        .toList();
        
    // Sort by Levenshtein distance for visual similarity challenge
    validPool.sort((a, b) => 
      _levenshtein(correctWord.translation, a.translation).compareTo(
      _levenshtein(correctWord.translation, b.translation))
    );
      
    final candidates = validPool.take(6).toList()..shuffle(rng);
    
    // Take up to 3 distractors for 3-4 options total
    final wrong = candidates.take(3).toList();
    
    // In PicturePick, we want full Words not strings. 
    // The UI handles whatever length is passed up to 4.
    return [correctWord, ...wrong]..shuffle(rng);
  }
}

