import 'package:flutter/material.dart';
import 'ai_chat_screen.dart'; // 채팅 화면 import
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:convert' show utf8;

enum Gender { male, female }

// API 호출 결과에 대한 응답 모델
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({required this.success, required this.message, this.data});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    try {
      return ApiResponse(
        success: json['status'] == 'success',
        message: json['message'] ?? '알 수 없는 응답',
        data: json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : null,
      );
    } catch (e) {
      // JSON 파싱 실패 시 기본 오류 응답 반환
      return ApiResponse(
        success: false,
        message: '응답 처리 중 오류 발생: $e',
        data: null,
      );
    }
  }
}

class NewPlanInputScreen extends StatefulWidget {
  const NewPlanInputScreen({super.key});

  @override
  State<NewPlanInputScreen> createState() => _NewPlanInputScreenState();
}

class _NewPlanInputScreenState extends State<NewPlanInputScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // API 서버 URL (실제 배포 시에는 환경 변수 또는 설정 파일로 관리하는 것이 좋음)
  final String apiUrl = 'http://localhost:1234/api/travel-plans/';
  
  // 로딩 상태 변수 추가
  bool _isLoading = false;

  // 입력 값 변수
  String? _selectedAgeGroup;
  Gender? _selectedGender;
  DateTimeRange? _travelDates;
  TimeOfDay? _departureTime;
  TimeOfDay? _arrivalTime;
  int? _numberOfTravelers;
  String? _accommodationLocation;

  // 연령대 목록
  final List<String> _ageGroups = ['10대', '20대', '30대', '40대', '50대 이상'];

  // 날짜 선택 함수
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // 2년 후까지 선택 가능
      // TODO: 기존 디자인 시스템 테마 적용
    );
    if (picked != null && picked != _travelDates) {
      setState(() {
        _travelDates = picked;
      });
    }
  }

  // 시간 선택 함수
  Future<void> _selectTime(BuildContext context, bool isDeparture) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      // TODO: 기존 디자인 시스템 테마 적용
    );
    if (picked != null) {
      setState(() {
        if (isDeparture) {
          _departureTime = picked;
        } else {
          _arrivalTime = picked;
        }
      });
    }
  }

  // 확인 대화 상자 표시 함수
  Future<void> _showConfirmationDialog() async {
    // 이 함수는 이제 모든 유효성 검사를 통과한 후에만 호출됩니다.
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('확인'),
          content: const Text('다음 페이지로 진행하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // 취소
              child: const Text('취소'),
              // TODO: 기존 디자인 시스템 스타일 적용
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // 확인
              child: const Text('확인'),
              // TODO: 기존 디자인 시스템 스타일 적용
            ),
          ],
          // TODO: 기존 디자인 시스템 스타일 적용
        );
      },
    );

    if (confirmed == true) {
      // '확인' 시 _navigateToChatScreen 호출은 "다음" 버튼 로직에서 직접 처리
       _navigateToChatScreen();
    }
  }

  // API 서버로 데이터 전송 함수
  Future<bool> _sendDataToServer(Map<String, dynamic> planData) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // HTTP POST 요청 보내기
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(planData),
      );

      setState(() {
        _isLoading = false;
      });

      // 응답 확인
      if (response.statusCode == 200 || response.statusCode == 201) {
        // UTF-8로 명시적 디코딩 처리
        final String decodedBody = utf8.decode(response.bodyBytes);
        final apiResponse = ApiResponse.fromJson(jsonDecode(decodedBody));
        
        // 서버에서 받은 데이터 처리 및 표시
        String successMessage = apiResponse.message;
        
        // 한국어 날짜 범위가 있으면 추가 정보로 표시
        if (apiResponse.data != null && apiResponse.data!.containsKey('kr_date_range')) {
          final String koreanDateRange = apiResponse.data!['kr_date_range'] as String;
          final String days = apiResponse.data!['days'] as String;
          successMessage += '\n선택한 여행 기간: $koreanDateRange ($days)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '확인',
              textColor: Colors.white,
              onPressed: () {
                // 스낵바 닫기
              },
            ),
          ),
        );
        return true;
      } else {
        // 오류 응답도 UTF-8로 디코딩
        final String decodedError = utf8.decode(response.bodyBytes);
        // 오류 처리
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('서버 오류: ${response.statusCode} - $decodedError'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return false;
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // 예외 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('네트워크 오류: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    }
  }

  // 채팅 화면으로 이동하는 함수
  Future<void> _navigateToChatScreen({bool skip = false}) async {
    Map<String, dynamic> planData = {};
    
    if (!skip) {
      // 건너뛰기가 아니고, 유효성 검사를 이미 통과했으므로 바로 저장
      _formKey.currentState!.save(); // TextFormField 값 저장 (나이 제외)
      
      planData = {
        'ageGroup': _selectedAgeGroup,
        'gender': _selectedGender?.toString().split('.').last,
        'travelStartDate': _travelDates?.start.toIso8601String(),
        'travelEndDate': _travelDates?.end.toIso8601String(),
        'departureTime': _departureTime != null ? '${_departureTime!.hour}:${_departureTime!.minute}' : null,
        'arrivalTime': _arrivalTime != null ? '${_arrivalTime!.hour}:${_arrivalTime!.minute}' : null,
        'numberOfTravelers': _numberOfTravelers,
        'accommodationLocation': _accommodationLocation,
      };
      
      print('입력 데이터: $planData');
      
      // 서버로 데이터 전송 (실제 구현 시 활성화)
      final result = await _sendDataToServer(planData);
      if (!result) {
        // 전송 실패 시 에러 처리
        return; // 전송 실패 시 화면 전환하지 않음
      }
    } else {
      print('입력 건너뛰기');
    }

    // 화면 전환
    if (!mounted) return; // 비동기 작업 후 위젯이 여전히 마운트 되어 있는지 확인
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiChatScreen(initialPlanData: planData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 여행 플랜 정보 입력'),
        elevation: 2.0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 섹션 타이틀 추가
                          const Text('기본 정보', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 16.0),
                          
                          // 나이 입력 -> 연령대 선택으로 변경
                          const Text('연령대', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8.0),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Wrap( // 공간에 따라 자동 줄바꿈
                              spacing: 8.0, // 가로 간격
                              runSpacing: 8.0, // 세로 간격
                              children: _ageGroups.map((ageGroup) {
                                return ChoiceChip(
                                  label: Text(ageGroup),
                                  selected: _selectedAgeGroup == ageGroup,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedAgeGroup = ageGroup;
                                      });
                                    }
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _selectedAgeGroup == ageGroup ? const Color(0xFF1E3A8A) : Colors.black87,
                                    fontWeight: _selectedAgeGroup == ageGroup ? FontWeight.bold : FontWeight.normal,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // 성별 선택 (칩으로 변경)
                          const Text('성별', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8.0),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ChoiceChip(
                                  label: const Text('남성'),
                                  selected: _selectedGender == Gender.male,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedGender = Gender.male;
                                      });
                                    }
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _selectedGender == Gender.male ? const Color(0xFF1E3A8A) : Colors.black87,
                                    fontWeight: _selectedGender == Gender.male ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ChoiceChip(
                                  label: const Text('여성'),
                                  selected: _selectedGender == Gender.female,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedGender = Gender.female;
                                      });
                                    }
                                  },
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: _selectedGender == Gender.female ? const Color(0xFF1E3A8A) : Colors.black87,
                                    fontWeight: _selectedGender == Gender.female ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // 섹션 타이틀 추가
                          const Text('여행 정보', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                          const SizedBox(height: 16.0),

                          // 여행 기간 선택 (Date Range Picker) - 디자인 개선
                          const Text('여행 기간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8.0),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _travelDates != null ? Colors.grey[100] : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _travelDates == null
                                        ? '여행 기간을 선택해주세요'
                                        : '${_travelDates!.start.toString().substring(0, 10)} - ${_travelDates!.end.toString().substring(0, 10)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _travelDates == null ? Colors.grey : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _selectDateRange(context),
                                  child: const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24.0),

                          // 왕복 출발-도착 시간 선택 (Time Picker) - 디자인 개선
                          const Text('여행 시간', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _departureTime != null ? Colors.grey[100] : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('한국 출국 시간', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _selectTime(context, true),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _departureTime?.format(context) ?? '선택',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: _departureTime == null ? Colors.grey : Colors.black87,
                                              ),
                                            ),
                                            const Icon(Icons.access_time, size: 18, color: Color(0xFF1E3A8A)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _arrivalTime != null ? Colors.grey[100] : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('일본 출국 시간', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _selectTime(context, false),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _arrivalTime?.format(context) ?? '선택',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: _arrivalTime == null ? Colors.grey : Colors.black87,
                                              ),
                                            ),
                                            const Icon(Icons.access_time, size: 18, color: Color(0xFF1E3A8A)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24.0),

                          // 여행 인원 입력 (숫자 입력 필드) - 디자인 개선
                          const Text('여행 인원', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8.0),
                          TextFormField(
                            decoration: InputDecoration(
                              hintText: '인원 수 입력',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              suffixIcon: const Icon(Icons.group, color: Color(0xFF1E3A8A)),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return '여행 인원을 입력해주세요.';
                              if (int.tryParse(value) == null || int.parse(value) <= 0) return '1명 이상 입력해주세요.';
                              return null;
                            },
                            onSaved: (value) => _numberOfTravelers = int.tryParse(value!),
                          ),
                          const SizedBox(height: 24.0),

                          // 숙소 위치 입력 (텍스트 입력 필드) - 디자인 개선
                          const Text('숙소 위치 (선택사항)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8.0),
                          TextFormField(
                            decoration: InputDecoration(
                              hintText: '숙소 위치 입력',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              suffixIcon: const Icon(Icons.location_on, color: Color(0xFF1E3A8A)),
                            ),
                            onSaved: (value) => _accommodationLocation = value,
                          ),
                          const SizedBox(height: 32.0), // 더 넓은 여백 추가
                        ],
                      ),
                    ),
                  ),
                ),
                // 버튼 부분을 고정된 크기를 가진 Container로 변경
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: _isLoading ? null : () {
                              _navigateToChatScreen(skip: true);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            child: const Text('건너뛰기', style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () {
                              // 유효성 검사 및 다음 단계 로직
                              final isTextFormValid = _formKey.currentState?.validate() ?? false;
                              final isAgeGroupSelected = _selectedAgeGroup != null;
                              final isGenderSelected = _selectedGender != null;
                              final isDatesSelected = _travelDates != null;
                              final isDepartureTimeSelected = _departureTime != null;
                              final isArrivalTimeSelected = _arrivalTime != null;

                              if (isTextFormValid &&
                                  isAgeGroupSelected &&
                                  isGenderSelected &&
                                  isDatesSelected &&
                                  isDepartureTimeSelected &&
                                  isArrivalTimeSelected) {
                                _navigateToChatScreen();
                              } else {
                                // 유효성 검사 실패 시 사용자에게 알림
                                String errorMessage = '필수 항목을 모두 입력해주세요.';
                                if (!isAgeGroupSelected) errorMessage = '연령대를 선택해주세요.';
                                else if (!isGenderSelected) errorMessage = '성별을 선택해주세요.';
                                else if (!isDatesSelected) errorMessage = '여행 기간을 선택해주세요.';
                                else if (!isDepartureTimeSelected) errorMessage = '출발 시간을 선택해주세요.';
                                else if (!isArrivalTimeSelected) errorMessage = '도착 시간을 선택해주세요.';

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                );
                                print('유효성 검사 실패: $errorMessage');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('다음', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // 로딩 인디케이터
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 