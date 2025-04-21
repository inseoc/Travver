import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TravelPlanResultScreen extends StatefulWidget {
  final Map<String, dynamic> planData;

  const TravelPlanResultScreen({super.key, required this.planData});

  @override
  State<TravelPlanResultScreen> createState() => _TravelPlanResultScreenState();
}

class _TravelPlanResultScreenState extends State<TravelPlanResultScreen> {
  bool _isLoading = true;
  bool _isUpdating = false; // 계획 업데이트 중 상태
  Map<String, dynamic>? _travelPlan;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTravelPlan();
  }

  Future<void> _loadTravelPlan() async {
    // 실제로는 이미 생성된 여행 계획을 가져오는 로직
    // 여기서는 전달받은 planData를 사용
    setState(() {
      _isLoading = false;
      _travelPlan = widget.planData;
    });
  }

  // 수정 요청을 서버로 전송하는 함수
  Future<void> _sendEditRequest(String request) async {
    setState(() {
      _isUpdating = true; // 업데이트 시작
    });

    try {
      // 서버 API 엔드포인트 URL
      final url = Uri.parse('http://localhost:1234/api/plan/edit-request');
      
      // 요청 데이터 생성
      final requestData = {
        'planId': _travelPlan?['created_at'] ?? DateTime.now().toIso8601String(), // 계획 ID 또는 생성 시간으로 대체
        'editRequest': request,
      };
      
      // HTTP POST 요청 보내기
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(requestData),
      );
      
      // 응답 처리
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 성공적으로 요청 전송
        final responseData = jsonDecode(response.body);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? '수정 요청이 전송되었습니다.'),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 수정된 계획 확인을 위한 새로고침 기능을 추가할 수 있음
        // 지금은 간단히 몇 초 후 상태 업데이트
        Future.delayed(const Duration(seconds: 5), () {
          // 여기서 업데이트된 계획을 가져오는 API 호출 가능
        });
      } else {
        // 오류 발생
        print('API 오류: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정 요청 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      print('API 요청 예외 발생: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네트워크 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false; // 업데이트 종료
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('여행 계획'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // 공유 기능 구현
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공유 기능은 아직 준비 중입니다.'))
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('오류: $_errorMessage'))
              : Stack(
                  children: [
                    _buildTravelPlanContent(),
                    // 업데이트 중일 때 오버레이 표시
                    if (_isUpdating)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'AI가 여행 계획을 수정하고 있습니다...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildTravelPlanContent() {
    // 여행 기본 정보
    final String travelPeriod = _travelPlan?['days'] ?? '정보 없음';
    final String travelDates = '${_travelPlan?['start_date'] ?? ''} ~ ${_travelPlan?['end_date'] ?? ''}';
    final String location = _travelPlan?['accommodationLocation'] ?? '정보 없음';
    
    // 일정 정보 (실제로는 AI가 생성한 일정이 들어갈 부분)
    final List<dynamic> itinerary = _travelPlan?['itinerary'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 여행 계획 요약 카드
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '여행 기간: $travelPeriod',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('날짜: $travelDates'),
                  const SizedBox(height: 4),
                  Text('숙소 위치: $location'),
                  const SizedBox(height: 4),
                  Text('여행자 수: ${_travelPlan?['numberOfTravelers'] ?? 0}명'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 여행 선호도 표시
          if (_travelPlan?['preference'] != null) ...[
            const Text(
              '여행 선호도',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_travelPlan!['preference']),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // 일별 일정 표시
          const Text(
            '일별 일정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          // 일정이 없으면 로딩 중 표시
          if (itinerary.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('AI가 여행 일정을 생성하고 있습니다...'),
                  ],
                ),
              ),
            ),
            
          // 일별 일정 리스트
          ...List.generate(
            itinerary.isNotEmpty ? itinerary.length : 0,
            (index) => _buildDayItinerary(index + 1, itinerary[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildDayItinerary(int day, Map<String, dynamic> dayPlan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Day $day - ${dayPlan['date'] ?? ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...List.generate(
              dayPlan['activities']?.length ?? 0,
              (index) => _buildActivityItem(dayPlan['activities'][index]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${activity['time'] ?? ''}: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['title'] ?? ''),
                if (activity['description'] != null)
                  Text(
                    activity['description'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isUpdating ? null : () {
                // 일정 저장 기능
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('일정이 저장되었습니다.'))
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('일정 저장하기'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isUpdating ? null : () {
                // 일정 수정 요청 기능
                _showEditRequestDialog();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('일정 수정 요청'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditRequestDialog() {
    final TextEditingController _requestController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 수정 요청'),
        content: TextField(
          controller: _requestController,
          decoration: const InputDecoration(
            hintText: '수정하고 싶은 내용을 입력해주세요',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              // 수정 요청 텍스트가 비어있지 않은지 확인
              if (_requestController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _sendEditRequest(_requestController.text);
              } else {
                // 비어있으면 경고
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('수정 요청 내용을 입력해주세요.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('요청하기'),
          ),
        ],
      ),
    );
  }
} 