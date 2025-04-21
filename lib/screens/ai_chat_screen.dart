import 'package:flutter/material.dart';
import 'dart:async'; // Future.delayed 사용
import 'dart:convert'; // JSON 인코딩을 위해 추가
import 'package:http/http.dart' as http; // HTTP 요청을 위해 추가
import 'travel_plan_result_screen.dart'; // 결과 화면 import

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
  Map<String, dynamic> _generatedPlan = {}; // 생성된 여행 계획을 저장

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
      // 서버 API 엔드포인트 URL (실제 서버 주소로 변경 필요)
      final preferenceUrl = Uri.parse('http://localhost:1234/api/travel-plans/preferences');
      
      // 사용자 선호도 데이터 생성
      final preferenceData = {
        'userPreference': preference, // 사용자 선호도 메시지
      };
      
      // HTTP POST 요청 보내기 - 선호도 저장
      final preferenceResponse = await http.post(
        preferenceUrl,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(preferenceData),
      );
      
      // 선호도 저장 응답 처리
      if (preferenceResponse.statusCode == 200 || preferenceResponse.statusCode == 201) {
        print('선호도 저장 API 응답: ${preferenceResponse.body}');
        
        // 기존 여행 계획에 선호도 추가
        final updatedPlan = {
          ...widget.initialPlanData,
          'preference': preference,
        };
        
        // AI 응답 메시지 추가
        _addMessage('네, 알겠습니다. 여행 계획을 생성하고 있습니다...', false);
        
        // 여행 계획 생성 요청 API 호출
        await _requestTravelPlanGeneration(updatedPlan);
      } else {
        print('API 오류: ${preferenceResponse.statusCode} - ${preferenceResponse.body}');
        _addMessage('죄송합니다. 정보 전송 중 오류가 발생했습니다. 다시 시도해주세요.', false);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('API 요청 예외 발생: $error');
      _addMessage('네트워크 오류가 발생했습니다. 연결을 확인하고 다시 시도해주세요.', false);
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 여행 계획 생성 요청 API 호출
  Future<void> _requestTravelPlanGeneration(Map<String, dynamic> planData) async {
    try {
      // 실제 여행 계획 생성 API URL
      final generateUrl = Uri.parse('http://localhost:1234/api/generate-base-plan');
      
      // 여행 계획 생성 요청
      final generateResponse = await http.post(
        generateUrl,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(planData),
      );
      
      if (generateResponse.statusCode == 200 || generateResponse.statusCode == 201) {
        // 응답으로 받은 여행 계획 데이터 파싱
        final responseData = jsonDecode(generateResponse.body);
        
        // 생성된 여행 계획 저장
        _generatedPlan = responseData['data'] ?? {};
        
        // 계획 생성 완료 후 메시지 추가
        _addMessage('여행 계획이 생성되었습니다! 결과 화면으로 이동합니다.', false);
        
        // 잠시 후 결과 화면으로 이동
        Future.delayed(const Duration(seconds: 1), () {
          _navigateToResultScreen();
        });
      } else {
        // 에러 처리
        print('계획 생성 API 오류: ${generateResponse.statusCode} - ${generateResponse.body}');
        _addMessage('여행 계획 생성 중 오류가 발생했습니다. 다시 시도해주세요.', false);
        
        // 에러 발생 시에도 임시 데이터로 화면 전환
        _createSamplePlanData();
        Future.delayed(const Duration(seconds: 1), () {
          _navigateToResultScreen();
        });
      }
    } catch (error) {
      print('계획 생성 API 예외 발생: $error');
      _addMessage('여행 계획 생성 중 네트워크 오류가 발생했습니다.', false);
      
      // 예외 발생 시에도 임시 데이터로 화면 전환
      _createSamplePlanData();
      Future.delayed(const Duration(seconds: 1), () {
        _navigateToResultScreen();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 임시 샘플 데이터 생성 (API 연동 전 테스트용)
  void _createSamplePlanData() {
    // 기존 계획 데이터에 임시 일정 추가
    _generatedPlan = {
      ...widget.initialPlanData,
      'preference': _textController.text.isEmpty ? '선호도 정보 없음' : _textController.text,
      'itinerary': [
        {
          'date': widget.initialPlanData['start_date'] ?? '여행 첫째날',
          'activities': [
            {
              'time': '09:00',
              'title': '호텔 체크아웃 및 아침식사',
              'description': '호텔 레스토랑에서 아침식사'
            },
            {
              'time': '11:00',
              'title': '현지 관광지 방문',
              'description': '인기 관광지 방문'
            },
            {
              'time': '13:00',
              'title': '점심식사',
              'description': '현지 맛집에서 점심식사'
            }
          ]
        }
      ]
    };
  }

  // 사용자 메시지 전송 처리
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && !_isLoading) {
      _addMessage(text, true, addResponse: true);
      _textController.clear();
    }
  }

  // 결과 화면으로 이동하는 함수
  void _navigateToResultScreen() {
    // 생성된 여행 계획이 없으면 임시 데이터 생성
    if (_generatedPlan.isEmpty) {
      _createSamplePlanData();
    }
    
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(
        builder: (context) => TravelPlanResultScreen(
          planData: _generatedPlan,
        )
      )
    );
  }

  // 건너뛰기 기능
  void _skipAndGenerateDefault() {
    setState(() {
      _isLoading = true;
    });
    
    _addMessage('기본 여행 계획을 생성합니다...', false);
    
    // 기본 선호도 데이터로 API 호출
    _createSamplePlanData();
    
    // 잠시 후 결과 화면으로 이동
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isLoading = false;
      });
      _navigateToResultScreen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 채팅'),
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
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isLoading ? null : _sendMessage, // 로딩 중에는 비활성화
          ),
          TextButton(
              onPressed: _isLoading ? null : () { // 로딩 중에는 비활성화
                print('채팅 건너뛰기 선택됨');
                _skipAndGenerateDefault(); // 건너뛰기 시 기본 계획 생성
              },
              child: const Text('건너뛰기')
          )
        ],
      ),
    );
  }
} 