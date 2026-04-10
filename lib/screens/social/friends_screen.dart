import 'dart:async';
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
      body: RefreshIndicator(
        color: SeedlingColors.seedlingGreen,
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(pendingRequestsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: SeedlingColors.background,
              expandedHeight: 120.0,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: Text(
                  'Roots Network',
                  style: SeedlingTypography.heading2.copyWith(
                    color: SeedlingColors.textPrimary,
                    fontSize: 24,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                        SeedlingColors.background,
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SeedlingColors.seedlingGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_rounded, color: SeedlingColors.seedlingGreen),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (c) => _AddFriendDialog(ref: ref),
                    ),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Pending Requests
                  pendingAsync.when(
                    data: (pending) => pending.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PENDING REQUESTS',
                                style: SeedlingTypography.caption.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: SeedlingColors.warning,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...pending.map(
                                (friend) => _buildPendingCard(context, ref, friend),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error loading requests: $e'),
                  ),

                  // Friends Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'YOUR FOREST',
                        style: SeedlingTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      friendsAsync.when(
                        data: (friends) => Text(
                          '${friends.length} trees',
                          style: SeedlingTypography.caption.copyWith(
                            color: SeedlingColors.seedlingGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  friendsAsync.when(
                    data: (friends) => friends.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.park_outlined,
                                    size: 64,
                                    color: SeedlingColors.morningDew.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Your forest is quiet',
                                    style: SeedlingTypography.heading3.copyWith(
                                      color: SeedlingColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Grow together with friends',
                                    style: SeedlingTypography.body.copyWith(
                                      color: SeedlingColors.textSecondary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: friends
                                .map((friend) => _buildFriendCard(friend))
                                .toList(),
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error loading friends: $e'),
                  ),
                ]),
              ),
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
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.warning.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                Text(
                  'Wants to be your friend',
                  style: SeedlingTypography.caption,
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  color: SeedlingColors.success,
                ),
                onPressed: () async {
                  await ref
                      .read(socialServiceProvider)
                      .respondToRequest(friend.userId, true);
                  ref.invalidate(friendsProvider);
                  ref.invalidate(pendingRequestsProvider);
                },
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: SeedlingColors.error),
                onPressed: () async {
                  await ref
                      .read(socialServiceProvider)
                      .respondToRequest(friend.userId, false);
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
        boxShadow: [
          BoxShadow(
            color: SeedlingColors.seedlingGreen.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
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
                      border: Border.all(
                        color: SeedlingColors.cardBackground,
                        width: 2,
                      ),
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
                      color: SeedlingColors.sunlight,
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

  // Refactored to _AddFriendDialog using a separate class.
}

// ── Search Dialog with 400ms Debounce (#14) ─────────────────────────────────

class _AddFriendDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AddFriendDialog({required this.ref});

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  List<Friend> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final query = _searchController.text.trim();
      if (query == _searchQuery) return; // Unchanged block
      
      setState(() => _searchQuery = query);
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _error = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await widget.ref.read(socialServiceProvider).searchUsers(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SeedlingColors.cardBackground,
      title: Text('Find Friends', style: SeedlingTypography.heading3),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search loosely by name...',
                hintStyle: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: SeedlingColors.seedlingGreen),
                filled: true,
                fillColor: SeedlingColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_error != null)
              Text('Error: $_error', style: const TextStyle(color: SeedlingColors.error))
            else if (_searchQuery.isNotEmpty && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text('No users found.', style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary)),
              )
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: SeedlingColors.morningDew,
                        child: Text(
                          user.displayName.isNotEmpty ? user.displayName[0] : '?',
                          style: SeedlingTypography.heading3.copyWith(color: SeedlingColors.seedlingGreen),
                        ),
                      ),
                      title: Text(user.displayName, style: SeedlingTypography.body),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add_rounded, color: SeedlingColors.seedlingGreen),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          try {
                            await widget.ref.read(socialServiceProvider).sendFriendRequest(user.userId);
                            if (mounted) {
                              nav.pop();
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Friend request sent!'), backgroundColor: SeedlingColors.seedlingGreen),
                              );
                            }
                          } catch (e) {
                             messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary)),
        ),
      ],
    );
  }
}
