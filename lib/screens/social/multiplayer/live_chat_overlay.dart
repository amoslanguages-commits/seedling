import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/colors.dart';
import '../../../core/typography.dart';
import '../../../providers/multiplayer_provider.dart';
import '../../../models/multiplayer.dart';

class LiveChatOverlay extends ConsumerStatefulWidget {
  const LiveChatOverlay({super.key});

  @override
  ConsumerState<LiveChatOverlay> createState() => _LiveChatOverlayState();
}

class _LiveChatOverlayState extends ConsumerState<LiveChatOverlay> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isOpen = false;
  int _lastMessageCount = 0;
  bool _hasUnread = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    ref.read(activeSessionProvider.notifier).sendChatMessage(_controller.text.trim());
    _controller.clear();
    
    // Auto-scroll happens due to Rebuild, but giving it a tiny delay ensures the item is built.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const SizedBox.shrink();

    final messages = session.chatMessages;
    
    // Detect new messages when closed
    if (!_isOpen && messages.length > _lastMessageCount) {
      // Just received a new message while closed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasUnread = true);
      });
    }
    _lastMessageCount = messages.length;

    return Positioned(
      bottom: 20,
      right: 20,
      child: _isOpen ? _buildExpandedChat(messages) : _buildMinimisedBubble(messages),
    );
  }

  Widget _buildMinimisedBubble(List<LiveChatMessage> messages) {
    final lastMsg = messages.isNotEmpty ? messages.last : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isOpen = true;
          _hasUnread = false;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brief snippet of last message if unread
          if (_hasUnread && lastMsg != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      '${lastMsg.senderName}: ${lastMsg.message}',
                      style: SeedlingTypography.caption.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),

          // Action Button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [SeedlingColors.water, SeedlingColors.seedlingGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: SeedlingColors.water.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.forum_rounded, color: Colors.white, size: 28),
                if (_hasUnread)
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(color: SeedlingColors.warning, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedChat(List<LiveChatMessage> messages) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: SeedlingColors.background.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SeedlingColors.morningDew.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: SeedlingColors.morningDew.withOpacity(0.3))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Arena Chat', style: SeedlingTypography.heading3),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => setState(() => _isOpen = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              
              // Messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == 'current_user' || msg.senderId == 'host'; // MOCK detection
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? SeedlingColors.water.withOpacity(0.2) : SeedlingColors.cardBackground,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                          ),
                          border: Border.all(color: isMe ? SeedlingColors.water.withOpacity(0.5) : Colors.transparent),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(msg.senderName, style: SeedlingTypography.caption.copyWith(color: SeedlingColors.textSecondary, fontSize: 10)),
                            Text(msg.message, style: SeedlingTypography.body),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Input Segment
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: SeedlingTypography.body,
                        decoration: InputDecoration(
                          hintText: 'Say something...',
                          hintStyle: SeedlingTypography.body.copyWith(color: SeedlingColors.textSecondary),
                          filled: true,
                          fillColor: SeedlingColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: SeedlingColors.seedlingGreen,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
