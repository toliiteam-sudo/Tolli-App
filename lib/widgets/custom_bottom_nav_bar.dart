import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onPlusPressed;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onPlusPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEDF2F7),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 20,
                spreadRadius: 0,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x08063E9E),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Home (Index 0)
              _buildNavIcon(
                index: 0,
                asset: AppAssets.homeNavPng,
              ),

              // 2. Explore (Index 1)
              _buildNavIcon(
                index: 1,
                asset: AppAssets.activitiesNavPng,
              ),

              // 3. Center "+" Create Button (Index 2)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (onPlusPressed != null) {
                      onPlusPressed!();
                    } else {
                      onTap(2);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x35063E9E),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Venues (Index 3)
              _buildNavIcon(
                index: 3,
                iconData: Icons.stadium_outlined,
              ),

              // 5. Messages (Index 4)
              _buildNavIcon(
                index: 4,
                asset: AppAssets.communityNavPng,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon({
    required int index,
    String? asset,
    IconData? iconData,
  }) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primary : const Color(0xFF94A3B8);

    IconData fallbackIconForIndex(int idx) {
      switch (idx) {
        case 0:
          return Icons.home_rounded;
        case 1:
          return Icons.explore_rounded;
        case 3:
          return Icons.stadium_outlined;
        case 4:
          return Icons.forum_rounded;
        default:
          return Icons.grid_view_rounded;
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: iconData != null
                ? Icon(
                    iconData,
                    size: 22,
                    color: color,
                  )
                : Image.asset(
                    asset!,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    color: color,
                    errorBuilder: (ctx, err, stack) => Icon(
                      fallbackIconForIndex(index),
                      size: 22,
                      color: color,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
