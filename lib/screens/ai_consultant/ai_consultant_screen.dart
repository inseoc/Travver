import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme.dart';
import '../../models/models.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';

/// AI 컨설턴트 화면
/// - Travel Consultant Agent 기반 실시간 채팅 상담
class AiConsultantScreen extends StatefulWidget {
  const AiConsultantScreen({super.key});

  @override
  State<AiConsultantScreen> createState() => _AiConsultantScreenState();
}

class _AiConsultantScreenState extends State<AiConsultantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;

  final List<String> _quickQuestions = [
    '추천 맛집',
    '숙소 추천',
    '환율 알려줘',
    '이 말 번역해줘',
  ];

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage.assistant(
      id: const Uuid().v4(),
      content: '안녕하세요! AI 여행 컨설턴트입니다. 여행에 관해 궁금한 것이 있으시면 무엇이든 물어보세요.',
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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

  Future<void> _sendMessage([String? quickQuestion]) async {
    final text = quickQuestion ?? _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage.user(
        id: const Uuid().v4(),
        content: text,
      ));
      _messageController.clear();
      _isLoading = true;
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      // TODO: 실제 API 연동 시 아래 코드 활성화
      // final apiService = ApiService();
      // final tripProvider = context.read<TripProvider>();
      // final response = await apiService.sendChatMessage(
      //   message: text,
      //   history: _messages,
      //   tripId: tripProvider.currentTrip?.id,
      // );

      // 임시 응답 (실제로는 AI 응답이 옴)
      await Future.delayed(const Duration(seconds: 1));
      final response = _getDummyResponse(text);

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage.assistant(
            id: const Uuid().v4(),
            content: response,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage.assistant(
            id: const Uuid().v4(),
            content: '죄송합니다. 일시적인 오류가 발생했습니다. 다시 시도해주세요.',
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getDummyResponse(String question) {
    if (question.contains('맛집') || question.contains('음식')) {
      return '현재 위치 기준 추천 맛집입니다:\n\n'
          '1. 이치란 라멘 (평점 4.5)\n'
          '   - 돈코츠 라멘 전문점\n'
          '   - 24시간 운영\n\n'
          '2. 킨류라멘 (평점 4.3)\n'
          '   - 가성비 좋은 라멘집\n'
          '   - 도톤보리 인근\n\n'
          '방문하고 싶은 곳이 있으시면 말씀해주세요!';
    } else if (question.contains('숙소') || question.contains('호텔')) {
      return '추천 숙소 목록입니다:\n\n'
          '1. 호텔 그란비아 오사카\n'
          '   - 위치: JR 오사카역 직결\n'
          '   - 가격: 약 150,000원/박\n\n'
          '2. 도톤보리 호텔\n'
          '   - 위치: 도톤보리 도보 3분\n'
          '   - 가격: 약 80,000원/박\n\n'
          '예산과 선호하는 위치를 알려주시면 더 맞춤 추천해드릴게요!';
    } else if (question.contains('환율')) {
      return '현재 환율 정보입니다:\n\n'
          '🇯🇵 일본 엔 (JPY)\n'
          '1 JPY = 9.2원\n'
          '10,000원 = 약 1,087엔\n\n'
          '💡 팁: 공항보다 시내 환전소가 더 유리해요!';
    } else if (question.contains('번역')) {
      return '번역하고 싶은 문장을 알려주세요!\n\n'
          '예시:\n'
          '- "이 근처 화장실이 어디있나요?"\n'
          '- "계산해주세요"\n'
          '- "이거 얼마예요?"';
    } else {
      return '네, 무엇이든 도와드릴게요! 여행지 추천, 맛집, 숙소, 환율, 현지어 번역 등 궁금한 것이 있으시면 말씀해주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('AI 컨설턴트', style: AppTypography.subhead1),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // 채팅 영역
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppDimens.spacing16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // 빠른 질문 칩
          _buildQuickQuestions(),

          // 입력창
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppDimens.spacing12,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacing16,
            vertical: AppDimens.spacing12,
          ),
          decoration: BoxDecoration(
            color: isUser ? AppColors.accent : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge).copyWith(
              bottomRight: isUser ? const Radius.circular(4) : null,
              bottomLeft: !isUser ? const Radius.circular(4) : null,
            ),
          ),
          child: Text(
            message.content,
            style: AppTypography.body1.copyWith(
              color: isUser ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spacing12, right: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacing16,
            vertical: AppDimens.spacing12,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge).copyWith(
              bottomLeft: const Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(0),
              _buildDot(1),
              _buildDot(2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.3 + (value * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildQuickQuestions() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacing16),
        itemCount: _quickQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimens.spacing8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(_quickQuestions[index]),
            onPressed: () => _sendMessage(_quickQuestions[index]),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacing16,
                    vertical: AppDimens.spacing12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: AppDimens.spacing8),
            Material(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _isLoading ? null : () => _sendMessage(),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화 삭제'),
        content: const Text('모든 대화 내용을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
              });
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
