import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../controllers/auth_controller.dart';
import '../models/chat_message_model.dart';
import '../repositories/community_repository.dart';
import '../services/toli_share_service.dart';
import '../widgets/toli_confirmation_dialog.dart';

class CommunityChatScreen extends StatefulWidget {
  final String communityId;
  final String title;
  final String membersCount;
  final String avatarInitials;
  final bool isActivityGroup;
  final bool isInactive;
  final VoidCallback? onLeaveGroup;

  const CommunityChatScreen({
    super.key,
    this.communityId = 'global',
    this.title = 'Football Match',
    this.membersCount = '8 members',
    this.avatarInitials = 'FT',
    this.isActivityGroup = false,
    this.isInactive = false,
    this.onLeaveGroup,
  });

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAttachmentMenuOpen = false;
  bool _isUploadingImage = false;

  List<ChatMessageModel> _messages = [];
  StreamSubscription<List<ChatMessageModel>>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _initChatSubscription();
  }

  void _initChatSubscription() {
    _chatSubscription?.cancel();
    final user = FirebaseAuth.instance.currentUser;
    final currentUid = user?.uid ?? '';

    _chatSubscription = CommunityRepository()
        .watchCommunityMessages(
      communityId: widget.communityId,
      currentUid: currentUid,
    )
        .listen((realtimeMessages) {
      if (mounted) {
        setState(() {
          _messages = realtimeMessages;
        });

        // Auto-scroll if user is near bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            final maxScroll = _scrollController.position.maxScrollExtent;
            final currentScroll = _scrollController.offset;
            if (maxScroll - currentScroll <= 200 || currentScroll == 0) {
              _scrollController.animateTo(
                maxScroll,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _messageController.clear();

    final user = FirebaseAuth.instance.currentUser;
    final authState = AuthController.instance.state;

    if (user != null) {
      await CommunityRepository().sendCommunityMessage(
        communityId: widget.communityId,
        senderId: user.uid,
        senderName: authState.displayName.isNotEmpty ? authState.displayName : 'You',
        senderPhotoUrl: authState.avatarUrl ?? user.photoURL,
        text: text,
      );
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    HapticFeedback.lightImpact();
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (photo != null && mounted) {
        setState(() {
          _isUploadingImage = true;
        });

        final user = FirebaseAuth.instance.currentUser;
        final authState = AuthController.instance.state;

        final downloadUrl = await CommunityRepository().uploadChatImage(
          communityId: widget.communityId,
          imageFile: photo,
        );

        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }

        if (downloadUrl != null && user != null) {
          await CommunityRepository().sendImageMessage(
            communityId: widget.communityId,
            senderId: user.uid,
            senderName: authState.displayName.isNotEmpty ? authState.displayName : 'You',
            senderPhotoUrl: authState.avatarUrl ?? user.photoURL,
            imageUrl: downloadUrl,
            text: '📷 Photo',
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image error: ${e.toString().split('\n').first}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    return Container(
      width: 165,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            spreadRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAttachmentMenuItem(
            icon: Icons.camera_alt_rounded,
            label: 'Photo',
            onTap: () {
              setState(() {
                _isAttachmentMenuOpen = false;
              });
              _handlePickImage(ImageSource.camera);
            },
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildAttachmentMenuItem(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: () {
              setState(() {
                _isAttachmentMenuOpen = false;
              });
              _handlePickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodySubtitle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _openShareGroupSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share Community',
                  style: AppTypography.headline.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Share link container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'https://tolii.app/community/${widget.avatarInitials.toLowerCase()}',
                      style: AppTypography.bodySubtitle.copyWith(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ToliShareService.copyLink(
                        context,
                        url: 'https://tolii.app/community/${widget.avatarInitials.toLowerCase()}',
                        message: 'Community invite link copied!',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Copy',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Pills Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareOption(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'WhatsApp',
                  onTap: () {
                    Navigator.pop(ctx);
                    ToliShareService.shareCommunity(
                      context,
                      name: widget.title,
                      description: 'Join ${widget.title} on TOLII!',
                      handle: widget.avatarInitials.toLowerCase(),
                    );
                  },
                ),
                _buildShareOption(
                  icon: Icons.send_rounded,
                  label: 'Telegram',
                  onTap: () {
                    Navigator.pop(ctx);
                    ToliShareService.shareCommunity(
                      context,
                      name: widget.title,
                      description: 'Join ${widget.title} on TOLII!',
                      handle: widget.avatarInitials.toLowerCase(),
                    );
                  },
                ),
                _buildShareOption(
                  icon: Icons.groups_rounded,
                  label: 'Squads',
                  onTap: () {
                    Navigator.pop(ctx);
                    ToliShareService.shareCommunity(
                      context,
                      name: widget.title,
                      description: 'Join ${widget.title} on TOLII!',
                      handle: widget.avatarInitials.toLowerCase(),
                    );
                  },
                ),
                _buildShareOption(
                  icon: Icons.share_outlined,
                  label: 'More Options',
                  onTap: () {
                    Navigator.pop(ctx);
                    ToliShareService.shareCommunity(
                      context,
                      name: widget.title,
                      description: 'Join ${widget.title} on TOLII!',
                      handle: widget.avatarInitials.toLowerCase(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupOptionsMenu() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.title,
              style: AppTypography.headline.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.membersCount,
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_off_outlined, color: Color(0xFF475569), size: 20),
              ),
              title: const Text('Mute Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications muted for this group')),
                );
              },
            ),
            const SizedBox(height: 4),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.exit_to_app_rounded, color: Color(0xFFDC2626), size: 20),
              ),
              title: const Text(
                'Leave Group',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: Color(0xFFDC2626),
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLeaveGroup();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeaveGroup() {
    ToliConfirmationDialog.show(
      context,
      icon: Icons.exit_to_app_rounded,
      title: 'Leave Group?',
      message:
          'Are you sure you want to leave ${widget.title}? You will no longer receive messages or match updates.',
      confirmText: 'Leave',
      isDestructive: true,
      onConfirm: () {
        widget.onLeaveGroup?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You left ${widget.title}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom > 0
        ? MediaQuery.of(context).padding.bottom + 2
        : 10.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
        children: [
          Column(
            children: [
              // 1. Top Bar (Deep Blue #063E9E)
              Container(
                color: AppColors.primary,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Back Button
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Avatar & Title (Tapping opens GroupInfoScreen)
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.avatarInitials,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      widget.membersCount,
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 12,
                                        color: Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Share Button (Opens Share Group popup)
                        GestureDetector(
                          onTap: _openShareGroupSheet,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.share_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),

                        // 3-dots Menu Button (Hidden for activity group chats)
                        if (!widget.isActivityGroup)
                          GestureDetector(
                            onTap: _showGroupOptionsMenu,
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.more_vert_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Chat Messages List
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isAttachmentMenuOpen) {
                      setState(() {
                        _isAttachmentMenuOpen = false;
                      });
                    }
                  },
                  child: ListView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      if (_messages.isEmpty && !_isUploadingImage)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 80, bottom: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No messages yet',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Be the first to start the conversation!',
                                  style: AppTypography.caption.copyWith(
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // Date Chip: "TODAY"
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'TODAY',
                              style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ..._messages.map((msg) => _buildMessageBubble(msg)),
                        if (_isUploadingImage) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Uploading photo...',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              // 3. Bottom Input Bar (Read-only if inactive/expired)
              widget.isInactive
                  ? Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'This activity has ended. The chat is now closed.',
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Container(
                      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomInset),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                  children: [
                    // Plus Attachment Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isAttachmentMenuOpen = !_isAttachmentMenuOpen;
                        });
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _isAttachmentMenuOpen
                              ? const Color(0xFFE0F2FE)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isAttachmentMenuOpen
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Icon(
                          _isAttachmentMenuOpen
                              ? Icons.close_rounded
                              : Icons.add_rounded,
                          color: _isAttachmentMenuOpen
                              ? AppColors.primary
                              : const Color(0xFF64748B),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Input Box without Emoji
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _messageController,
                          maxLength: 1000,
                          style: AppTypography.bodySubtitle.copyWith(
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type something...',
                            hintStyle: AppTypography.caption.copyWith(
                              fontSize: 14,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            counterText: '',
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Send Button (Solid Deep Blue Circle)
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Dismiss Barrier when menu is open
          if (_isAttachmentMenuOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _isAttachmentMenuOpen = false;
                  });
                },
                child: const SizedBox.expand(),
              ),
            ),
            // Floating Attachment Menu positioned directly above + button
            Positioned(
              left: 14,
              bottom: bottomInset + 58,
              child: _buildAttachmentMenu(),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isMe = msg.isMe;
    final isImage = msg.type == 'image' || (msg.imageUrl != null && msg.imageUrl!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender Name
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              msg.sender,
              style: AppTypography.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMe ? AppColors.primary : const Color(0xFF475569),
              ),
            ),
          ),

          // Bubble Container
          if (isImage)
            GestureDetector(
              onTap: () => _showFullScreenImage(context, msg.imageUrl!),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                  maxHeight: 260,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    msg.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        color: const Color(0xFFF1F5F9),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 140,
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Color(0xFF94A3B8)),
                          SizedBox(width: 6),
                          Text('Failed to load image', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: AppTypography.bodySubtitle.copyWith(
                  fontSize: 14,
                  height: 1.4,
                  color: isMe ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          const SizedBox(height: 4),

          // Timestamp
          Text(
            msg.time,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
