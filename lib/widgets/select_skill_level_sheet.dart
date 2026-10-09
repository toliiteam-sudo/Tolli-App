import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/activity_model.dart';
import 'request_sent_sheet.dart';

class SelectSkillLevelSheet extends StatefulWidget {
  final ActivityModel activity;
  final Function(SkillLevel selectedSkill)? onConfirmed;

  const SelectSkillLevelSheet({
    super.key,
    required this.activity,
    this.onConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required ActivityModel activity,
    Function(SkillLevel)? onConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectSkillLevelSheet(
        activity: activity,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<SelectSkillLevelSheet> createState() => _SelectSkillLevelSheetState();
}

class _SelectSkillLevelSheetState extends State<SelectSkillLevelSheet> {
  late SkillLevel _selectedLevel;

  @override
  void initState() {
    super.initState();
    // Default selected level to Advanced or activity's skill level
    _selectedLevel = widget.activity.skillLevel == SkillLevel.allLevels
        ? SkillLevel.advanced
        : widget.activity.skillLevel;
  }

  String _getSkillDescription(SkillLevel level) {
    switch (level) {
      case SkillLevel.beginner:
        return 'Learning the basics and building confidence';
      case SkillLevel.intermediate:
        return 'Comfortable with rallies, rules, and scoring';
      case SkillLevel.advanced:
        return 'Competitive play with strong control and strategy';
      case SkillLevel.allLevels:
        return 'Suitable for players of any experience level';
    }
  }

  String _getHostLevelHeader(SkillLevel level) {
    switch (level) {
      case SkillLevel.advanced:
        return 'Advanced players only';
      case SkillLevel.intermediate:
        return 'Intermediate players only';
      case SkillLevel.beginner:
        return 'Beginner players only';
      case SkillLevel.allLevels:
        return 'All levels welcome';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag indicator line
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Text(
            'What’s your skill level?',
            style: AppTypography.headline.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            'Choose the level that best reflects your ${activity.title} experience.',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),

          // Host Requirement Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF1D4ED8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getHostLevelHeader(activity.skillLevel),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'The host set this level for the activity.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Radio options list
          ...[SkillLevel.beginner, SkillLevel.intermediate, SkillLevel.advanced].map((level) {
            final isSelected = _selectedLevel == level;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedLevel = level;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0040A8) : const Color(0xFFE2E8F0),
                      width: isSelected ? 2.0 : 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Radio circle header
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFF0040A8) : Colors.white,
                              border: isSelected
                                  ? null
                                  : Border.all(color: const Color(0xFFCBD5E1), width: 2),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        level.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFF0040A8) : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSkillDescription(level),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF0040A8),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),

          // Confirm skill level button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onConfirmed != null) {
                  widget.onConfirmed!(_selectedLevel);
                } else {
                  if (activity.isInviteOnly) {
                    RequestSentSheet.show(
                      context,
                      activity: activity,
                      selectedSkill: _selectedLevel,
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Confirm skill level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Footer note
          Center(
            child: Text(
              activity.isInviteOnly
                  ? 'Your request will be sent to the host for approval.'
                  : 'You will join the activity immediately.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
