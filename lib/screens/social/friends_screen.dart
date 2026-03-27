import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../models/social.dart';
import '../../providers/app_providers.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);
    
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Friends', style: SeedlingTypography.heading2),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddFriendDialog(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(pendingRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Pending Requests
            pendingAsync.when(
              data: (pending) => pending.isEmpty 
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pending Requests',
                          style: SeedlingTypography.heading3,
                        ),
                        const SizedBox(height: 15),
                        ...pending.map((friend) => _buildPendingCard(context, ref, friend)),
                        const SizedBox(height: 30),
                      ],
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading requests: $e'),
            ),
            
            // Friends List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Friends',
                  style: SeedlingTypography.heading3,
                ),
                friendsAsync.when(
                  data: (friends) => Text(
                    '${friends.length} friends',
                    style: SeedlingTypography.caption,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            friendsAsync.when(
              data: (friends) => friends.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('No friends yet. Add some!'),
                      ),
                    )
                  : Column(
                      children: friends.map((friend) => _buildFriendCard(friend)).toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading friends: $e'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPendingCard(BuildContext context, WidgetRef ref, Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SeedlingColors.sunlight),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: SeedlingColors.morningDew,
            child: Text(
              friend.displayName[0],
              style: SeedlingTypography.heading3.copyWith(
                color: SeedlingColors.seedlingGreen,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Wants to be your friend',
                  style: SeedlingTypography.caption,
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: SeedlingColors.success),
                onPressed: () async {
                  await ref.read(socialServiceProvider).respondToRequest(friend.userId, true);
                  ref.invalidate(friendsProvider);
                  ref.invalidate(pendingRequestsProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: SeedlingColors.error),
                onPressed: () async {
                  await ref.read(socialServiceProvider).respondToRequest(friend.userId, false);
                  ref.invalidate(pendingRequestsProvider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFriendCard(Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: SeedlingColors.morningDew,
                child: Text(
                  friend.displayName[0],
                  style: SeedlingTypography.heading3.copyWith(
                    color: SeedlingColors.seedlingGreen,
                  ),
                ),
              ),
              if (friend.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: SeedlingColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${friend.currentStreak} day streak',
                      style: SeedlingTypography.caption,
                    ),
                    if (!friend.isOnline && friend.lastActive != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '• ${_formatLastActive(friend.lastActive!)}',
                        style: SeedlingTypography.caption,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${friend.totalXP}',
                style: SeedlingTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: SeedlingColors.seedlingGreen,
                ),
              ),
              Text(
                'XP',
                style: SeedlingTypography.caption.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  String _formatLastActive(DateTime lastActive) {
    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Friend'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or email...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (value) async {
                      // Perform search
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  if (searchController.text.isNotEmpty)
                    FutureBuilder<List<Friend>>(
                      future: ref.read(socialServiceProvider).searchUsers(searchController.text),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        final results = snapshot.data ?? [];
                        if (results.isEmpty) {
                          return const Text('No users found.');
                        }
                        return Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final user = results[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: SeedlingColors.morningDew,
                                  child: Text(user.displayName[0]),
                                ),
                                title: Text(user.displayName),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final nav = Navigator.of(context);
                                    await ref.read(socialServiceProvider).sendFriendRequest(user.userId);
                                    if (context.mounted) {
                                      nav.pop();
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Friend request sent!')),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}
