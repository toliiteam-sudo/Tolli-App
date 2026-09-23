import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../controllers/activities_controller.dart';
import '../models/activity_model.dart';
import '../widgets/date_picker_bottom_sheet.dart';
import '../widgets/select_activity_sheet.dart';
import '../widgets/select_location_sheet.dart';
import '../widgets/time_picker_modal.dart';

class EditActivityScreen extends StatefulWidget {
  final ActivityModel activity;

  const EditActivityScreen({super.key, required this.activity});

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  late String _sportTitle;
  late String _sportIcon;
  late SportCategory _sportCategory;

  late String _venueName;
  late DateTime _selectedDate;
  late String _dateFormatted;

  late int _hour;
  late int _minute;
  late bool _isPm;
  late String _timeFormatted;

  late int _playersNeeded;
  late SkillLevel _selectedSkillLevel;
  late int _selectedCost;
  late bool _splitCost;
  late String _whoCanJoin;
  late TextEditingController _noteController;
  late TextEditingController _equipmentController;
  late int _durationMinutes;

  bool _isSaving = false;

  final List<SkillLevel> _skillLevels = [
    SkillLevel.allLevels,
    SkillLevel.beginner,
    SkillLevel.intermediate,
    SkillLevel.advanced,
  ];

  final List<int> _costOptions = [0, 60, 100, 150];
  final List<String> _joinOptions = ['Public', 'Friends', 'Invite only'];

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;

    _sportTitle = activity.title;
    _sportIcon = activity.iconAsset.isNotEmpty ? activity.iconAsset : AppAssets.actBoxCricket;
    _sportCategory = activity.sportCategory;

    _venueName = activity.venueName ?? 'Bhavnagar';
    _selectedDate = activity.date ?? DateTime(2025, 8, 24);

    final parts = activity.subtitle.split(' · ');
    _dateFormatted = parts.isNotEmpty ? parts[0] : 'Saturday, 24 Aug';
    _timeFormatted = parts.length > 1 ? parts[1] : '6:30 PM';

    _hour = 6;
    _minute = 30;
    _isPm = true;

    _playersNeeded = activity.totalPlayers;
    _selectedSkillLevel = activity.skillLevel;
    _selectedCost = activity.pricePerPerson;
    _splitCost = true;
    _whoCanJoin = activity.isInviteOnly ? 'Invite only' : 'Public';
    _noteController = TextEditingController(text: activity.note);
    _equipmentController = TextEditingController(text: activity.equipment.isNotEmpty ? activity.equipment : 'None');
    _durationMinutes = activity.durationMinutes > 0 ? activity.durationMinutes : 60;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  void _openSelectActivity() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<ActivitySelectionItem>(
      MaterialPageRoute(
        builder: (_) => SelectActivitySheet(currentSelected: _sportTitle),
      ),
    );
    if (result != null) {
      setState(() {
        _sportTitle = result.title;
        _sportIcon = result.iconAsset;
        _sportCategory = result.sportCategory;
      });
    }
  }

  void _openSelectLocation() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<LocationVenueItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectLocationSheet(currentSelectedVenue: _venueName),
    );
    if (result != null) {
      setState(() {
        _venueName = result.name;
      });
    }
  }

  void _openDatePicker() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DatePickerBottomSheet(initialDate: _selectedDate),
    );
    if (result != null) {
      setState(() {
        _selectedDate = result['date'] as DateTime;
        _dateFormatted = result['formatted'] as String;
      });
    }
  }

  void _openTimePicker() async {
    HapticFeedback.lightImpact();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TimePickerModal(
        initialHour: _hour,
        initialMinute: _minute,
        initialIsPm: _isPm,
      ),
    );
    if (result != null) {
      setState(() {
        _hour = result['hour'] as int;
        _minute = result['minute'] as int;
        _isPm = result['isPm'] as bool;
        _timeFormatted = result['formatted'] as String;
      });
    }
  }

  void _saveActivity() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSaving = true;
    });

    int hour24 = _isPm ? (_hour % 12 + 12) : (_hour % 12);
    final startTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour24,
      _minute,
    );

    final updatedActivity = widget.activity.copyWith(
      title: _sportTitle,
      subtitle: '$_dateFormatted · $_timeFormatted · $_venueName',
      iconAsset: _sportIcon,
      sportCategory: _sportCategory,
      skillLevel: _selectedSkillLevel,
      totalPlayers: _playersNeeded,
      pricePerPerson: _selectedCost,
      note: _noteController.text.trim(),
      date: startTimestamp,
      venueName: _venueName,
      isInviteOnly: _whoCanJoin == 'Invite only',
      equipment: _equipmentController.text.trim().isEmpty ? 'None' : _equipmentController.text.trim(),
      durationMinutes: _durationMinutes,
    );

    await ActivitiesController().updateActivity(updatedActivity);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Activity updated successfully!', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(updatedActivity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 36), // Balanced alignment
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Grouped Information Card (Activity, Where, Date, Time)
                    _buildGroupedInfoCard(),
                    const SizedBox(height: 14),

                    // 2. Players Needed Card
                    _buildPlayersNeededCard(),
                    const SizedBox(height: 16),

                    // 3. Skill Level Section
                    _buildSkillLevelSection(),
                    const SizedBox(height: 16),

                    // 4. Cost Per Person Card
                    _buildCostCard(),
                    const SizedBox(height: 16),

                    // 5. Who Can Join Card
                    _buildWhoCanJoinCard(),
                    const SizedBox(height: 16),

                    // 6. Add a Note Section
                    _buildNoteSection(),
                    const SizedBox(height: 14),

                    // 7. Equipment Needed Section
                    _buildEquipmentSection(),
                    const SizedBox(height: 20),

                    // 8. Save Button CTA
                    _buildSaveButtonCTA(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Grouped Information Card
  Widget _buildGroupedInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _formItemRow(
            label: 'Activity',
            value: _sportTitle,
            iconWidget: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(7),
              ),
              padding: const EdgeInsets.all(5),
              child: Image.asset(_sportIcon, fit: BoxFit.contain, errorBuilder: (ctx, err, stack) => const Icon(Icons.sports_cricket_rounded, size: 16, color: AppColors.primary)),
            ),
            onTap: _openSelectActivity,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          _formItemRow(
            label: 'Where?',
            value: _venueName,
            iconWidget: const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            onTap: _openSelectLocation,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          _formItemRow(
            label: 'Date',
            value: _dateFormatted,
            iconWidget: const Icon(
              Icons.calendar_today_outlined,
              size: 17,
              color: AppColors.primary,
            ),
            onTap: _openDatePicker,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          _formItemRow(
            label: 'Time',
            value: _timeFormatted,
            iconWidget: const Icon(
              Icons.access_time_rounded,
              size: 17,
              color: AppColors.primary,
            ),
            onTap: _openTimePicker,
          ),
          const SizedBox(height: 4),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Estimated duration · 1 hour',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _formItemRow({
    required String label,
    required String value,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: label,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            iconWidget,
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // 2. Players Needed Card
  Widget _buildPlayersNeededCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Players needed',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  GestureDetector(
                    onTap: _playersNeeded > 2
                        ? () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _playersNeeded--;
                            });
                          }
                        : null,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _playersNeeded > 2
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          width: 1.4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.remove,
                        size: 15,
                        color: _playersNeeded > 2
                            ? AppColors.primary
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$_playersNeeded',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _playersNeeded++;
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'How many people can join?',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 1),
          const Text(
            'Minimum players · 4',
            style: TextStyle(
              fontSize: 10.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Skill Level Section
  Widget _buildSkillLevelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SKILL LEVEL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _skillLevels.map((skill) {
            final bool isSelected = _selectedSkillLevel == skill;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedSkillLevel = skill;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  skill.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // 4. Cost Per Person Card
  Widget _buildCostCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COST PER PERSON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ..._costOptions.map((cost) {
                  final bool isSelected = _selectedCost == cost;
                  final label = cost == 0 ? 'Free' : '₹$cost';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedCost = cost;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final controller = TextEditingController();
                    final customVal = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        title: const Text(
                          'Enter Custom Cost',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          maxLength: 7,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            prefixText: '₹ ',
                            hintText: 'e.g. 200',
                            counterText: '',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: () {
                              final parsed = int.tryParse(controller.text.trim());
                              Navigator.of(ctx).pop(parsed);
                            },
                            child: const Text('OK', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (customVal != null && customVal >= 0) {
                      setState(() {
                        _selectedCost = customVal;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: !_costOptions.contains(_selectedCost)
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: !_costOptions.contains(_selectedCost)
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      !_costOptions.contains(_selectedCost)
                          ? '₹$_selectedCost'
                          : 'Custom',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !_costOptions.contains(_selectedCost)
                            ? Colors.white
                            : AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 8),

          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Split cost',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Split venue cost between players',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _splitCost,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _splitCost = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Who Can Join Card
  Widget _buildWhoCanJoinCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHO CAN JOIN?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: _joinOptions.map((opt) {
                final bool isSelected = _whoCanJoin == opt;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _whoCanJoin = opt;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(width: 6),
              Text(
                'Anyone nearby can discover and join',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Add a Note Section
  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ADD A NOTE (OPTIONAL)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            controller: _noteController,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              hintText: 'Add note for participants...',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              isDense: true,
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  void _openCustomDurationPicker() async {
    HapticFeedback.lightImpact();
    int initialHours = _durationMinutes ~/ 60;
    int initialMins = _durationMinutes % 60;
    final hoursCtrl = TextEditingController(text: '$initialHours');
    final minsCtrl = TextEditingController(text: '$initialMins');

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Custom Duration', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hours', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      TextField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Minutes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      TextField(
                        controller: minsCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final hrs = int.tryParse(hoursCtrl.text.trim()) ?? 0;
              final mins = int.tryParse(minsCtrl.text.trim()) ?? 0;
              final total = (hrs * 60) + mins;
              if (total > 0 && total <= 1440) {
                Navigator.of(ctx).pop(total);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter valid duration (1 min - 24 hrs)')),
                );
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      setState(() {
        _durationMinutes = result;
      });
    }
  }

  // 7. Equipment Needed Section
  Widget _buildEquipmentSection() {
    final presetValues = [30, 60, 90, 120, 180];
    final durationOptions = [
      {'val': 30, 'label': '30m'},
      {'val': 60, 'label': '1h'},
      {'val': 90, 'label': '1.5h'},
      {'val': 120, 'label': '2h'},
      {'val': 180, 'label': '3h'},
    ];

    final bool isCustomSelected = !presetValues.contains(_durationMinutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DURATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              ...durationOptions.map((opt) {
                final val = opt['val'] as int;
                final label = opt['label'] as String;
                final isSelected = _durationMinutes == val;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _durationMinutes = val;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Custom option
              GestureDetector(
                onTap: _openCustomDurationPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isCustomSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCustomSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    isCustomSelected ? '${_durationMinutes ~/ 60}h ${_durationMinutes % 60}m' : 'Custom',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isCustomSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isCustomSelected ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'EQUIPMENT NEEDED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: TextField(
            controller: _equipmentController,
            maxLength: 100,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
            ),
            decoration: const InputDecoration(
              hintText: 'e.g. None, Bring your own racket, Football...',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              isDense: true,
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }

  // 8. Save Button CTA
  Widget _buildSaveButtonCTA() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isSaving ? null : _saveActivity,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can edit the details later.',
          style: TextStyle(
            fontSize: 11.5,
            color: Color(0xFF94A3B8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
