import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/services/api_service.dart';

/// A beautiful floating chatbot widget that provides campus navigation assistance.
class ChatBotWidget extends StatefulWidget {
  /// Callback when the chatbot returns locations to display
  final void Function(List<ChatBotLocation> locations, String action)?
  onLocationsReturned;

  const ChatBotWidget({super.key, this.onLocationsReturned});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final FocusNode _focusNode = FocusNode();

  bool _isOpen = false;
  bool _isLoading = false;
  int _rateLimitCooldown = 0;
  Timer? _cooldownTimer;

  // All available suggestion chips
  static const List<String> _allSuggestions = [
    'Where is the library?',
    'Find ICTC Building',
    'Canteen location',
    'Dean Office',
    'Where is the gym?',
    'Find the hostel',
    'Main entrance',
    'Computer lab',
    'Robotics Club',
    'Football ground',
    'ATM location',
    'Exam office',
  ];

  // Current 3 random suggestions
  late List<String> _currentSuggestions;

  late AnimationController _panelAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _fabRotationAnimation;

  @override
  void initState() {
    super.initState();
    _shuffleSuggestions();

    _panelAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _scaleAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _panelAnimationController,
      curve: Curves.easeOut,
    );

    _fabRotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _panelAnimationController.dispose();
    _fabAnimationController.dispose();
    _pulseAnimationController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _shuffleSuggestions() {
    final random = Random();
    final shuffled = List<String>.from(_allSuggestions)..shuffle(random);
    _currentSuggestions = shuffled.take(3).toList();
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _shuffleSuggestions(); // Get new random suggestions each time
        _panelAnimationController.forward();
        _fabAnimationController.forward();
        _pulseAnimationController.stop();
        // Scroll to bottom to show latest messages when reopening
        _scrollToBottom();
      } else {
        _panelAnimationController.reverse();
        _fabAnimationController.reverse();
        _pulseAnimationController.repeat();
        _focusNode.unfocus();
      }
    });
  }

  /// Close the chatbot panel programmatically
  void _closeChat() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _panelAnimationController.reverse();
        _fabAnimationController.reverse();
        _pulseAnimationController.repeat();
        _focusNode.unfocus();
      });
    }
  }

  void _startCooldown(int seconds) {
    setState(() {
      _rateLimitCooldown = seconds;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _rateLimitCooldown--;
        if (_rateLimitCooldown <= 0) {
          _rateLimitCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendMessage() async {
    final query = _messageController.text.trim();
    if (query.isEmpty || _isLoading || _rateLimitCooldown > 0) return;

    setState(() {
      _messages.add(ChatMessage(content: query, role: ChatMessageRole.user));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final response = await _apiService.chatBot(query);

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (response.success && response.data != null) {
        _messages.add(
          ChatMessage(
            content: response.data!.message,
            role: ChatMessageRole.assistant,
            locations: response.data!.locations,
            action: response.data!.action,
          ),
        );

        if (response.data!.locations.isNotEmpty) {
          widget.onLocationsReturned?.call(
            response.data!.locations,
            response.data!.action,
          );
          // Auto-close chatbot after navigating to location
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _closeChat();
          });
        }
      } else {
        final isQuotaError = response.isQuotaError;
        if (isQuotaError) {
          _startCooldown(30);
        }
        _messages.add(
          ChatMessage(
            content: isQuotaError
                ? '⏱️ API limit reached. Please wait ${_rateLimitCooldown > 0 ? _rateLimitCooldown : 30} seconds.'
                : response.errorMessage ??
                      'Something went wrong. Please try again.',
            role: ChatMessageRole.error,
            isQuotaError: isQuotaError,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    return Stack(
      children: [
        // Chat Panel
        if (_isOpen)
          Positioned(
            right: 16,
            bottom: 78,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: Alignment.bottomRight,
                child: _buildChatPanel(),
              ),
            ),
          ),

        // FAB Button
        Positioned(right: 16, bottom: 16, child: _buildFab()),
      ],
    );
  }

  Widget _buildFab() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimationController,
        _fabAnimationController,
      ]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Ripple 1
            if (!_isOpen)
              Opacity(
                opacity: (1 - _pulseAnimationController.value) * 0.5,
                child: Transform.scale(
                  scale: 1 + (_pulseAnimationController.value * 0.5),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF667EEA).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            // Ripple 2
            if (!_isOpen)
              Opacity(
                opacity:
                    (1 -
                        (_pulseAnimationController.value + 0.5).clamp(0, 1.5) %
                            1) *
                    0.3,
                child: Transform.scale(
                  scale:
                      1 + (((_pulseAnimationController.value + 0.5) % 1) * 0.8),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF764BA2).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

            // Main Button Container
            Transform.scale(
              scale: _isOpen
                  ? 1.0
                  : 1 + (_pulseAnimationController.value * 0.05),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF764BA2).withValues(alpha: 0.3),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleChat,
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated Border
                        if (!_isOpen)
                          RotationTransition(
                            turns: _pulseAnimationController,
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                        // Icon
                        RotationTransition(
                          turns: _fabRotationAnimation,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: _isOpen
                                ? const Icon(
                                    Icons.close_rounded,
                                    key: ValueKey('close'),
                                    size: 26,
                                    color: Colors.white,
                                  )
                                : const Icon(
                                    Icons.assistant_rounded,
                                    key: ValueKey('open'),
                                    size: 24,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatPanel() {
    return Container(
      width: 360,
      height: 520,
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color?.withValues(alpha: 0.98) ??
            Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessagesList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(Icons.assistant, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campus Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF4ADE80,
                            ).withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Powered by AI',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleChat,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF667EEA).withValues(alpha: 0.15),
                    const Color(0xFF764BA2).withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_outlined,
                color: Color(0xFF667EEA),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hello there! 👋',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me about buildings, departments,\nor directions around Pulchowk Campus.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _currentSuggestions
                  .map((s) => _buildSuggestionChip(s))
                  .toList(),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildLoadingBubble();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _messageController.text = text;
          _sendMessage();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF667EEA).withValues(alpha: 0.1),
                const Color(0xFF764BA2).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF667EEA).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == ChatMessageRole.user;
    final isError = message.role == ChatMessageRole.error;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                )
              : null,
          color: isUser
              ? null
              : isError
              ? const Color(0xFFFEE2E2)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isError
                      ? const Color(0xFFFCA5A5)
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                ),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? const Color(0xFF667EEA).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : isError
                ? const Color(0xFFDC2626)
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return _buildTypingDot(index);
          }),
        ),
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 200)),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_rateLimitCooldown > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rate limited. Retry in $_rateLimitCooldown s',
                    style: const TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFFF3F4F6)
                        : const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    enabled: !_isLoading && _rateLimitCooldown <= 0,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: _rateLimitCooldown > 0
                          ? 'Wait $_rateLimitCooldown s...'
                          : 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: (_isLoading || _rateLimitCooldown > 0)
                        ? [Colors.grey.shade300, Colors.grey.shade400]
                        : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: (_isLoading || _rateLimitCooldown > 0)
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(
                              0xFF667EEA,
                            ).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_isLoading || _rateLimitCooldown > 0)
                        ? null
                        : _sendMessage,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : _rateLimitCooldown > 0
                          ? Text(
                              '$_rateLimitCooldown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
