import 'package:flutter/material.dart';

/// The same primary destinations remain available inside the immersive flow.
class CompanionBottomNavigation extends StatelessWidget {
  const CompanionBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.immersive = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool immersive;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '她',
          ),
          NavigationDestination(
            icon: Icon(immersive
                ? Icons.meeting_room_outlined
                : Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(immersive
                ? Icons.meeting_room_rounded
                : Icons.chat_bubble_rounded),
            label: immersive ? '房间' : '聊天',
          ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: '更多',
          ),
        ],
      );
}
