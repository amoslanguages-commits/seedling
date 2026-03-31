import 'package:flutter/material.dart';
import '../models/taxonomy.dart';
import '../models/word.dart';
import '../core/colors.dart';
import '../core/typography.dart';

// ================ CATEGORY FILTER WIDGET ================

class CategoryFilterWidget extends StatefulWidget {
  final Function(List<String> selectedCategories) onFilterChanged;
  final List<String> initialSelected;
  
  const CategoryFilterWidget({
    super.key,
    required this.onFilterChanged,
    this.initialSelected = const [],
  });
  
  @override
  State<CategoryFilterWidget> createState() => _CategoryFilterWidgetState();
}

class _CategoryFilterWidgetState extends State<CategoryFilterWidget> {
  late List<String> _selectedIds;
  String? _expandedParentId;
  
  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.initialSelected);
  }
  
  void _toggleCategory(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    widget.onFilterChanged(_selectedIds);
  }
  
  @override
  Widget build(BuildContext context) {
    final rootCategories = CategoryTaxonomy.getRootCategories();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: SeedlingTypography.heading3,
        ),
        const SizedBox(height: 15),
        
        // Root categories with expand/collapse
        ...rootCategories.map((cat) => _buildCategoryTile(cat)),
        
        if (_selectedIds.isNotEmpty) ...[
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedIds.map((id) {
              final cat = CategoryTaxonomy.getCategory(id);
              if (cat == null) return const SizedBox.shrink();
              
              return Chip(
                label: Text(cat.name, style: SeedlingTypography.caption.copyWith(color: cat.color)),
                backgroundColor: cat.color.withValues(alpha: 0.1),
                deleteIconColor: cat.color,
                onDeleted: () => _toggleCategory(id),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
  
  Widget _buildCategoryTile(SemanticCategory category) {
    final isSelected = _selectedIds.contains(category.id);
    final isExpanded = _expandedParentId == category.id;
    final subCategories = CategoryTaxonomy.getSubCategories(category.id);
    final hasChildren = subCategories.isNotEmpty;
    
    return Column(
      children: [
        GestureDetector(
          onTap: () => _toggleCategory(category.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? category.color.withValues(alpha: 0.1)
                  : SeedlingColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? category.color : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: SeedlingTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasChildren)
                        Text(
                          '${subCategories.length} subcategories',
                          style: SeedlingTypography.caption,
                        ),
                    ],
                  ),
                ),
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedParentId = isExpanded ? null : category.id;
                      });
                    },
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more,
                        color: SeedlingColors.textSecondary,
                      ),
                    ),
                  ),
                if (isSelected)
                  Icon(Icons.check_circle, color: category.color),
              ],
            ),
          ),
        ),
        
        // Subcategories
        if (isExpanded && hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              children: subCategories.map((sub) => _buildSubCategoryTile(sub)).toList(),
            ),
          ),
      ],
    );
  }
  
  Widget _buildSubCategoryTile(SemanticCategory category) {
    final isSelected = _selectedIds.contains(category.id);
    
    return GestureDetector(
      onTap: () => _toggleCategory(category.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected 
              ? category.color.withValues(alpha: 0.1)
              : SeedlingColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? category.color.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(category.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.name,
                style: SeedlingTypography.body,
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: category.color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ================ PART OF SPEECH FILTER ================

class POSFilterWidget extends StatelessWidget {
  final List<PartOfSpeech> selectedPOS;
  final Function(List<PartOfSpeech>) onChanged;
  final String languageCode;
  
  const POSFilterWidget({
    super.key,
    required this.selectedPOS,
    required this.onChanged,
    required this.languageCode,
  });
  
  @override
  Widget build(BuildContext context) {
    final relevantPOS = _getRelevantPOS(languageCode);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Part of Speech',
          style: SeedlingTypography.heading3,
        ),
        const SizedBox(height: 15),
        
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: relevantPOS.map((pos) => _buildPOSChip(pos)).toList(),
        ),
      ],
    );
  }
  
  List<PartOfSpeech> _getRelevantPOS(String languageCode) {
    final universal = [
      PartOfSpeech.noun,
      PartOfSpeech.verb,
      PartOfSpeech.adjective,
      PartOfSpeech.adverb,
    ];
    
    switch (languageCode) {
      case 'ja': return [...universal, PartOfSpeech.particle, PartOfSpeech.classifier];
      case 'ko': return [...universal, PartOfSpeech.postposition, PartOfSpeech.particle];
      case 'zh': return [...universal, PartOfSpeech.classifier, PartOfSpeech.particle];
      default: return universal;
    }
  }
  
  Widget _buildPOSChip(PartOfSpeech pos) {
    final isSelected = selectedPOS.contains(pos);
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pos.icon),
          const SizedBox(width: 6),
          Text(pos.displayName),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        final newList = List<PartOfSpeech>.from(selectedPOS);
        if (selected) {
          newList.add(pos);
        } else {
          newList.remove(pos);
        }
        onChanged(newList);
      },
      selectedColor: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
      checkmarkColor: SeedlingColors.seedlingGreen,
      labelStyle: SeedlingTypography.caption.copyWith(
        color: isSelected ? SeedlingColors.seedlingGreen : SeedlingColors.textPrimary,
      ),
    );
  }
}

// ================ WORD CARD WITH MULTIPLE CATEGORIES ================

class EnhancedWordCard extends StatelessWidget {
  final Word word;
  final VoidCallback? onTap;
  
  const EnhancedWordCard({
    super.key,
    required this.word,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final primaryCat = word.primaryCategory;
    final allCategories = word.getAllCategories();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryCat?.color.withValues(alpha: 0.3) ?? Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.deepRoot.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...word.partsOfSpeech.take(2).map((pos) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SeedlingColors.morningDew.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${pos.icon} ${pos.displayName}',
                    style: SeedlingTypography.caption.copyWith(fontSize: 10),
                  ),
                )),
                const Spacer(),
                Row(
                  children: allCategories.take(3).map((cat) => 
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(cat.icon),
                    ),
                  ).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              word.word,
              style: SeedlingTypography.heading2,
            ),
            const SizedBox(height: 2),
            Text(
              word.translation,
              style: SeedlingTypography.body.copyWith(
                color: SeedlingColors.textSecondary,
              ),
            ),
            if (allCategories.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: allCategories.map((cat) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cat.name,
                    style: SeedlingTypography.caption.copyWith(
                      color: cat.color,
                      fontSize: 10,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
