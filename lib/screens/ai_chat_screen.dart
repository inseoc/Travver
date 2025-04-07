import 'package:flutter/material.dart';
import 'dart:async'; // Future.delayed 사용
import 'dart:convert'; // JSON 인코딩을 위해 추가
import 'package:http/http.dart' as http; // HTTP 요청을 위해 추가

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
  bool _isLoading = false; // API 요청 상태를 관리하기 위한 변수

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
      // 사용자 메시지를 API로 전송
      _sendUserPreferenceToAPI(text);
    }
  }

  // 사용자 선호도를 API로 전송하는 함수
  Future<void> _sendUserPreferenceToAPI(String preference) async {
    setState(() {
      _isLoading = true; // 로딩 상태 시작
    });

    try {
      // API 엔드포인트 URL (실제 서버 주소로 변경 필요)
      final url = Uri.parse('http://localhost:1234/api/travel-plans/preferences');
      
      // 사용자 선호도 메시지와 기존 여행 계획 데이터를 합쳐서 전송
      final dataToSend = {
        ...widget.initialPlanData, // 기존 여행 계획 데이터
        'userPreference': preference, // 사용자 선호도 메시지 추가
      };
      
      // HTTP POST 요청 보내기
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(dataToSend),
      );
      
      // 응답 처리
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('API 응답: ${response.body}');
        
        // AI 응답 메시지 추가
        _addMessage('네, 알겠습니다. 해당 정보를 반영하겠습니다.', false);
        
        // 잠시 후 다음 화면으로 이동
        Future.delayed(const Duration(seconds: 1), () {
          _navigateToNextScreen();
        });
      } else {
        print('API 오류: ${response.statusCode} - ${response.body}');
        _addMessage('죄송합니다. 정보 전송 중 오류가 발생했습니다. 다시 시도해주세요.', false);
      }
    } catch (error) {
      print('API 요청 예외 발생: $error');
      _addMessage('네트워크 오류가 발생했습니다. 연결을 확인하고 다시 시도해주세요.', false);
    } finally {
      setState(() {
        _isLoading = false; // 로딩 상태 종료
      });
    }
  }

  // 사용자 메시지 전송 처리
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !_isLoading) {
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
          // 로딩 표시
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator()),
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
              enabled: !_isLoading, // 로딩 중에는 비활성화
              // TODO: 기존 디자인 시스템 스타일 적용
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isLoading ? null : _sendMessage, // 로딩 중에는 비활성화
            // TODO: 기존 디자인 시스템 아이콘/버튼 스타일 적용
          ),
          TextButton(
              onPressed: _isLoading ? null : () { // 로딩 중에는 비활성화
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