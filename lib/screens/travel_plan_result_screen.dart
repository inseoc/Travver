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
  Map<String, dynamic>? _travelPlanData; // API에서 받아온 일별 일정 데이터 
  String? _errorMessage;
  // 각 일자별 확장 상태 저장 (true = 펼침, false = 접힘)
  Map<String, bool> _expandedDays = {};

  @override
  void initState() {
    super.initState();
    _loadTravelPlan();
  }

  Future<void> _loadTravelPlan() async {
    try {
      // 기존 여행 계획 데이터 로드
      setState(() {
        _isLoading = true;
      });
      
      // 디버깅을 위한 데이터 출력
      print('플랜 데이터 구조: ${widget.planData}');
      
      // 서버에서 받은 데이터 파싱
      final travelPlanData = widget.planData;
      
      // 데이터 구조 확인
      if (travelPlanData.containsKey('DAY1') || travelPlanData.keys.any((key) => key.startsWith('DAY'))) {
        // 데이터가 이미 {DAY1: [...], DAY2: [...]} 형태인 경우
        setState(() {
          _travelPlan = {"data": travelPlanData}; // 여행 기본 정보용 래퍼
          _travelPlanData = travelPlanData; // 일정 데이터 직접 사용
          
          print('일정 데이터 키: ${_travelPlanData!.keys.toList()}');
          
          // 초기 확장 상태 설정 (DAY1은 펼침, 나머지는 접음)
          _expandedDays = {};
          _travelPlanData!.keys.forEach((day) {
            _expandedDays[day] = day == 'DAY1';
          });
          print('초기 확장 상태: $_expandedDays');
          
          _isLoading = false;
        });
      } else if (travelPlanData.containsKey('data')) {
        // 기존 예상 구조: {"status": "success", "message": "...", "data": {...}}
        final apiData = travelPlanData['data'];
        
        if (apiData is Map<String, dynamic>) {
          setState(() {
            _travelPlan = travelPlanData;
            _travelPlanData = apiData;
            
            // 초기 확장 상태 설정 (DAY1은 펼침, 나머지는 접음)
            _expandedDays = {};
            _travelPlanData!.keys.forEach((day) {
              _expandedDays[day] = day == 'DAY1';
            });
            print('초기 확장 상태: $_expandedDays');
            
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = '일정 데이터 형식이 올바르지 않습니다.';
          });
        }
      } else {
        print('지원되지 않는 데이터 형식: $travelPlanData');
        setState(() {
          _isLoading = false;
          _errorMessage = '지원되지 않는 데이터 형식입니다.';
        });
      }
    } catch (e) {
      print('데이터 로드 예외: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '데이터 로드 중 오류가 발생했습니다: $e';
      });
    }
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
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? '수정 요청이 전송되었습니다.'),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 수정된 계획 확인을 위한 새로고침 기능을 추가할 수 있음
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

  // [추가] 파워J 모드(상세 일정) 요청 함수
  Future<void> _requestComprehensivePlan() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      // 상세 일정 생성 API 호출
      final url = Uri.parse('http://localhost:1234/api/generate-comprehensive-plan');
      
      // POST 요청 (필요 시 body에 현재 planId 등을 포함할 수 있음)
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (responseBody['status'] == 'success') {
          final newPlanData = responseBody['data'];
          
          setState(() {
            // 받아온 상세 일정으로 데이터 업데이트
            // 기존 메타데이터는 유지하고 일정 부분(_travelPlanData)만 교체
            _travelPlanData = newPlanData;
            
            // 확장 상태 초기화 (DAY1 펼침)
            _expandedDays = {};
            if (_travelPlanData != null) {
               _travelPlanData!.keys.forEach((day) {
                _expandedDays[day] = day == 'DAY1';
              });
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('파워J 모드: 상세 일정이 생성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print('API 오류: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('상세 일정 요청 예외: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네트워크 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdating = false;
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
                                'AI가 여행 계획을 고도화하고 있습니다...',
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
    // 여행 기본 정보를 추출하지만, 없을 수 있음을 고려
    final basicInfoAvailable = _travelPlan?['data'] != null && (_travelPlan?['data'] is Map<String, dynamic>);
    
    // UI 구성
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 여행 계획 요약 카드 - 기본 정보가 있을 때만 표시
          if (basicInfoAvailable) ...[
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
                    if (_travelPlan?['data']?['days'] != null)
                      Text(
                        '여행 기간: ${_travelPlan?['data']?['days']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if ((_travelPlan?['data']?['start_date'] != null) || (_travelPlan?['data']?['end_date'] != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('날짜: ${_travelPlan?['data']?['start_date'] ?? ''} ~ ${_travelPlan?['data']?['end_date'] ?? ''}'),
                      ),
                    if (_travelPlan?['data']?['accommodationLocation'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('숙소 위치: ${_travelPlan?['data']?['accommodationLocation']}'),
                      ),
                    if (_travelPlan?['data']?['numberOfTravelers'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('여행자 수: ${_travelPlan?['data']?['numberOfTravelers']}명'),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 여행 선호도 표시
            if (_travelPlan?['data']?['preference'] != null && _travelPlan!['data']['preference'].toString().isNotEmpty) ...[
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
                  child: Text(_travelPlan!['data']['preference'].toString()),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
          
          // 일별 일정 표시
          const Text(
            '일별 일정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // 일정이 없거나 로딩 중인 경우
          if (_travelPlanData == null || _travelPlanData!.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('일정 정보가 없습니다.'),
                  ],
                ),
              ),
            )
          else
            _buildDailyItineraryExpansion(),
        ],
      ),
    );
  }

// 일별 일정을 접고 펼칠 수 있는 ExpansionPanelList 위젯
  Widget _buildDailyItineraryExpansion() {
    // 정렬된 DAY 키 목록 (DAY1, DAY2, DAY3, ...)
    // DAY1, DAY2, DAY10 순서로 정렬하기 위해 숫자 비교 로직 추가 (선택 사항, 기본 문자열 정렬도 동작함)
    final sortedDays = _travelPlanData!.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    
    return ExpansionPanelList(
      elevation: 1,
      expandedHeaderPadding: const EdgeInsets.all(0), // 펼쳐졌을 때 헤더 패딩 제거
      expansionCallback: (index, isExpanded) {
        setState(() {
          final day = sortedDays[index];
          // isExpanded는 탭 당시의 상태입니다. 
          // 닫혀있음(false) -> 탭 -> 열려야 함(true)
          // 열려있음(true) -> 탭 -> 닫혀야 함(false)
          // 따라서 !isExpanded 값을 할당하는 것이 맞지만, 
          // 안전하게 현재 상태를 반전시키는 로직을 사용합니다.
          _expandedDays[day] = !(_expandedDays[day] ?? false);
        });
      },
      children: sortedDays.map<ExpansionPanel>((day) {
        // 데이터 형식이 List가 아닐 경우 예외 처리
        if (_travelPlanData![day] is! List) {
             return ExpansionPanel(
                headerBuilder: (context, isExpanded) => const ListTile(title: Text("Error")),
                body: const SizedBox(),
                isExpanded: false,
             );
        }

        final activities = _travelPlanData![day] as List<dynamic>;
        final isExpanded = _expandedDays[day] ?? false;
        
        return ExpansionPanel(
          isExpanded: isExpanded,
          canTapOnHeader: true, // 헤더 전체 탭 가능
          headerBuilder: (context, isExpanded) {
            // [수정] ListTile 대신 Container + Row 사용
            // ListTile이 탭 이벤트를 가로채는 문제를 방지합니다.
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    '${activities.length}개 일정',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },
          body: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              children: activities.map<Widget>((activity) {
                final time = activity['time'] ?? '';
                final location = activity['location'] ?? '';
                final description = activity['description'] ?? '';
                
                return ListTile(
                  dense: true, // 리스트 간격 조밀하게
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Text(
                    time,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  title: Text(
                    location,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(description),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  // [수정됨] 하단 버튼 영역: 계획 수정하기(왼쪽) + 파워J 모드(오른쪽)
  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 왼쪽: 계획 수정하기
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('계획 수정하기'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                ),
                onPressed: _isUpdating ? null : () {
                  _showEditRequestDialog();
                },
              ),
            ),
            const SizedBox(width: 12), // 버튼 사이 간격
            // 오른쪽: 파워J 모드
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flash_on), // 번개 아이콘 등 강조
                label: const Text('파워J 모드'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFFF59E0B), // 강조 색상 (Amber/Orange)
                  foregroundColor: Colors.white,
                ),
                onPressed: _isUpdating ? null : () {
                  _requestComprehensivePlan(); // 상세 일정 API 호출
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRequestDialog() {
    final TextEditingController editController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Text('여행 계획 수정 요청'),
            const SizedBox(width: 8),
            Tooltip(
              message: '변경 또는 추가하고 싶은 여행 계획 내용을 AI에게 알려주시면 알맞게 수정됩니다.',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {},
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: '예: 첫째 날 오후에 쇼핑 시간을 더 넣어주세요.',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (editController.text.trim().isNotEmpty) {
                      Navigator.pop(context);
                      _sendEditRequest(editController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('요청하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}