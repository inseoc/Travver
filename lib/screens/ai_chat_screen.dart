import 'package:flutter/material.dart';
import 'dart:async'; // Future.delayed 사용

// 채팅 메시지 모델
class ChatMessage {
  final String text;
  final bool isUserMessage;

  ChatMessage({required this.text, required this.isUserMessage});
}

class AiChatScreen extends StatefulWidget {
  final Map<String, dynamic> initialPlanData; // 이전 화면에서 받은 데이터

  const AiChatScreen({super.key, required this.initialPlanData});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // 스크롤 컨트롤러

  @override
  void initState() {
    super.initState();
    // 초기 AI 메시지 추가
    _addMessage('선호하시는 여행 스타일 또는 추가 정보를 자유롭게 입력해주세요.', false);

    print('전달받은 데이터: ${widget.initialPlanData}');
  }

  // 메시지 추가 및 스크롤 자동 이동 함수
  void _addMessage(String text, bool isUserMessage, {bool addResponse = false}) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUserMessage: isUserMessage));
    });

    // 메시지 추가 후 스크롤을 맨 아래로 이동
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // 사용자 메시지 후 AI 응답 추가 및 다음 화면 이동 로직
    if (isUserMessage && addResponse) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMessage('네, 알겠습니다. 해당 정보를 반영하겠습니다.', false);

        // AI 응답 후 잠시 뒤 다음 화면으로 이동 (예시)
        Future.delayed(const Duration(seconds: 1), () {
          _navigateToNextScreen();
        });
      });
    }
  }

  // 사용자 메시지 전송 처리
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      _addMessage(text, true, addResponse: true);
      _textController.clear();
    }
  }

  // 다음 화면으로 이동하는 함수 (예시)
  void _navigateToNextScreen() {
    print('다음 화면으로 이동합니다.');
    // TODO: 실제 다음 화면으로 이동하는 Navigator 로직 구현
    // 예를 들어, 결과 화면이나 플랜 상세 화면 등
    // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResultScreen()));

    // 임시로 이전 화면으로 돌아가기
    if(Navigator.canPop(context)){
      Navigator.pop(context);
      // 이전 화면(Input)도 닫기
      if(Navigator.canPop(context)){
          Navigator.pop(context);
      }
    }


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 채팅'),
        // TODO: 기존 디자인 시스템에 맞는 AppBar 스타일 적용
      ),
      body: Column(
        children: [
          // 채팅 메시지 목록
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // 스크롤 컨트롤러 연결
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          // 입력 영역
          _buildInputArea(),
        ],
      ),
    );
  }

  // 메시지 버블 위젯 빌드
  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: message.isUserMessage
              ? Theme.of(context).primaryColorLight // 사용자 메시지 색상
              : Colors.grey[300], // AI 메시지 색상
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUserMessage ? Colors.black87 : Colors.black87,
            // TODO: 기존 디자인 시스템 폰트 스타일 적용
          ),
        ),
      ),
    );
  }

  // 입력 영역 위젯 빌드
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4.0,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: '메시지 입력...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
              // TODO: 기존 디자인 시스템 스타일 적용
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            // TODO: 기존 디자인 시스템 아이콘/버튼 스타일 적용
          ),
          TextButton(
              onPressed: () {
                print('채팅 건너뛰기 선택됨');
                _navigateToNextScreen(); // 건너뛰기 시 다음 화면 이동
              },
              child: const Text('건너뛰기')
              // TODO: 기존 디자인 시스템 스타일 적용
          )
        ],
      ),
    );
  }
} 