import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../controllers/activities_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import '../widgets/date_picker_bottom_sheet.dart';
import '../widgets/select_activity_sheet.dart';
import '../widgets/time_picker_modal.dart';
import 'activity_created_screen.dart';
import 'browse_locations_screen.dart';
import 'select_location_screen.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  bool _isCreating = false;

  // 1. Grouped Card State
  String _sportTitle = 'Box Cricket';
  String _sportIcon = AppAssets.actBoxCricket;
  SportCategory _sportCategory = SportCategory.boxCricket;

  String _venueName = 'Bhavnagar';
  late DateTime _selectedDate;
  late String _dateFormatted;

  int _hour = 6;
  int _minute = 30;
  bool _isPm = true;
  String _timeFormatted = '6:30 PM';

  // 2. Players Counter
  int _playersNeeded = 8;

  // 3. Skill Level
  SkillLevel _selectedSkillLevel = SkillLevel.allLevels;
  final List<SkillLevel> _skillLevels = [
    SkillLevel.allLevels,
    SkillLevel.beginner,
    SkillLevel.intermediate,
    SkillLevel.advanced,
  ];

  // 4. Cost Per Person
  int _selectedCost = 100;
  final List<int> _costOptions = [0, 60, 100, 150];
  bool _splitCost = true;

  // 5. Who Can Join
  String _whoCanJoin = 'Public';
  final List<String> _joinOptions = ['Public', 'Invite only'];

  // 6. Note & Equipment
  final TextEditingController _noteController = TextEditingController(
    text: 'Casual box cricket game. No experience needed — just come and play!',
  );
  final TextEditingController _equipmentController = TextEditingController(
    text: 'None',
  );

  // 7. Duration
  int _durationMinutes = 60;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _dateFormatted = 'Today, ${_selectedDate.day} ${_getMonthName(_selectedDate.month)}';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }

  @override
  void dispose() {
    _noteController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  void _openSelectActivity() async {
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
    final result = await Navigator.of(context).push<LocationVenueItem>(
      MaterialPageRoute(
        builder: (_) => SelectLocationScreen(currentSelectedVenue: _venueName),
      ),
    );
    if (result != null) {
      setState(() {
        _venueName = result.name;
      });
    }
  }

  void _openDatePicker() async {
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

  Future<void> _createActivity() async {
    if (_isCreating) return;

    final user = FirebaseAuth.instance.currentUser;
    final authState = AuthController.instance.state;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to create an activity')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    int hour24 = _isPm ? (_hour % 12 + 12) : (_hour % 12);
    final startTimestamp = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour24,
      _minute,
    );

    final newActivity = ActivityModel(
      id: '',
      title: _sportTitle,
      subtitle: '$_dateFormatted · $_timeFormatted · $_venueName',
      iconAsset: _sportIcon,
      sportCategory: _sportCategory,
      skillLevel: _selectedSkillLevel,
      joinedPlayers: 1,
      totalPlayers: _playersNeeded,
      pricePerPerson: _selectedCost,
      note: _noteController.text.trim(),
      date: startTimestamp,
      isHost: true,
      hostId: user.uid,
      hostName: authState.displayName.isNotEmpty ? authState.displayName : 'Host',
      hostUsername: authState.username,
      hostPhotoUrl: authState.avatarUrl ?? user.photoURL,
      venueName: _venueName,
      venueLocation: '$_venueName · Bhavnagar',
      venueConfirmed: true,
      equipment: _equipmentController.text.trim().isEmpty ? 'None' : _equipmentController.text.trim(),
      durationMinutes: _durationMinutes,
      status: 'scheduled',
    );

    try {
      final activityId = await ActivityRepository().createActivity(
        activity: newActivity,
        hostUid: user.uid,
        hostName: authState.displayName.isNotEmpty ? authState.displayName : 'Host',
        hostUsername: authState.username,
        hostPhotoUrl: authState.avatarUrl ?? user.photoURL,
      );

      if (!mounted) return;

      if (activityId != null) {
        final createdActivity = newActivity.copyWith(id: activityId);
        ActivitiesController().addActivity(createdActivity);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActivityCreatedScreen(activity: createdActivity),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create activity: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
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
                      width: 40,
                      height: 40,
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
                        size: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Create Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Bring people together',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40), // Balanced alignment
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Grouped Information Card (Activity, Where, Date, Time) ──
                    _buildGroupedInfoCard(),
                    const SizedBox(height: 12),

                    // ── 2. Players Needed Card ──
                    _buildPlayersNeededCard(),
                    const SizedBox(height: 14),

                    // ── 3. Skill Level Section ──
                    _buildSkillLevelSection(),
                    const SizedBox(height: 14),

                    // ── 4. Cost Per Person Card ──
                    _buildCostCard(),
                    const SizedBox(height: 14),

                    // ── 5. Who Can Join Card ──
                    _buildWhoCanJoinCard(),
                    const SizedBox(height: 14),

                    // ── 6. Add a Note Section ──
                    _buildNoteSection(),
                    const SizedBox(height: 14),

                    // ── 7. Equipment Needed Section ──
                    _buildEquipmentSection(),
                    const SizedBox(height: 18),

                    // ── 8. Create Button CTA ──
                    _buildCreateButtonCTA(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ─────────────────────────────────────────
  // 1. Grouped Information Card
  // ─────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity row
          _formItemRow(
            label: 'Activity',
            value: _sportTitle,
            iconWidget: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              child: Image.asset(_sportIcon, fit: BoxFit.contain),
            ),
            onTap: _openSelectActivity,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // Where row
          _formItemRow(
            label: 'Where?',
            value: _venueName,
            iconWidget: const Icon(
              Icons.location_on_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            onTap: _openSelectLocation,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // Date row
          _formItemRow(
            label: 'Date',
            value: _dateFormatted,
            iconWidget: const Icon(
              Icons.calendar_today_outlined,
              size: 19,
              color: AppColors.primary,
            ),
            onTap: _openDatePicker,
          ),
          const Divider(color: Color(0xFFF1F5F9), height: 1),

          // Time row
          _formItemRow(
            label: 'Time',
            value: _timeFormatted,
            iconWidget: const Icon(
              Icons.access_time_rounded,
              size: 19,
              color: AppColors.primary,
            ),
            onTap: _openTimePicker,
          ),
          const SizedBox(height: 4),

          // Estimated duration helper
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Estimated duration · 1 hour',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          const SizedBox(height: 4),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const TextSpan(
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
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14.5,
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
            const SizedBox(width: 6),
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

  // ─────────────────────────────────────────
  // 2. Players Needed Card
  // ─────────────────────────────────────────
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),

              // Counter (-  count  +)
              Row(
                children: [
                  GestureDetector(
                    onTap: _playersNeeded > 2
                        ? () {
                            setState(() {
                              _playersNeeded--;
                            });
                          }
                        : null,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _playersNeeded > 2
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.remove,
                        size: 16,
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
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _playersNeeded++;
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'How many people can join?',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Minimum players · 4',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 3. Skill Level Section
  // ─────────────────────────────────────────
  Widget _buildSkillLevelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SKILL LEVEL',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
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
                setState(() {
                  _selectedSkillLevel = skill;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

  // ─────────────────────────────────────────
  // 4. Cost Per Person Card
  // ─────────────────────────────────────────
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COST PER PERSON',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // Chips Row: Free, ₹60, ₹100, ₹150, Custom
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
                        setState(() {
                          _selectedCost = cost;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7.5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Custom option
                GestureDetector(
                  onTap: () async {
                    final controller = TextEditingController();
                    final customVal = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(
                          'Enter Custom Cost',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          maxLength: 7,
                          style: const TextStyle(fontSize: 15),
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
                            onPressed: () {
                              final parsed = int.tryParse(controller.text.trim());
                              Navigator.of(ctx).pop(parsed);
                            },
                            child: const Text('OK'),
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
                      vertical: 7.5,
                    ),
                    decoration: BoxDecoration(
                      color: !_costOptions.contains(_selectedCost)
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
          const SizedBox(height: 10),

          // Split cost Switch Row
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Split cost',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Split venue cost between players',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _splitCost,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
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

  // ─────────────────────────────────────────
  // 5. Who Can Join Card
  // ─────────────────────────────────────────
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHO CAN JOIN?',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),

          // Segmented selector container
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: _joinOptions.map((opt) {
                final bool isSelected = _whoCanJoin == opt;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _whoCanJoin = opt;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.5),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
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

          // Info message
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _whoCanJoin == 'Public'
                      ? 'Anyone nearby can discover and join'
                      : 'Only invited users can join or request access',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 6. Add a Note Section
  // ─────────────────────────────────────────
  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ADD A NOTE (OPTIONAL)',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
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
              fontSize: 14.5,
              color: AppColors.textDark,
              height: 1.35,
            ),
            decoration: const InputDecoration(
              hintText: 'Add note for participants...',
              hintStyle: TextStyle(
                fontSize: 14,
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

  // ─────────────────────────────────────────
  // 7. Equipment Section
  // ─────────────────────────────────────────
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
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
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
                      setState(() {
                        _durationMinutes = val;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
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
                          fontSize: 14,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
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
                      fontSize: 14,
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
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
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
              fontSize: 14.5,
              color: AppColors.textDark,
            ),
            decoration: const InputDecoration(
              hintText: 'e.g. None, Bring your own racket, Football...',
              hintStyle: TextStyle(
                fontSize: 14,
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

  // ─────────────────────────────────────────
  // 8. Create Button CTA
  // ─────────────────────────────────────────
  Widget _buildCreateButtonCTA() {
    return Column(
      children: [
        GestureDetector(
          onTap: _createActivity,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'Create Activity',
              style: TextStyle(
                fontSize: 16,
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
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
