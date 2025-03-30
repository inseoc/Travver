import 'package:flutter/material.dart';
import 'ai_chat_screen.dart'; // 채팅 화면 import

enum Gender { male, female }

class NewPlanInputScreen extends StatefulWidget {
  const NewPlanInputScreen({super.key});

  @override
  State<NewPlanInputScreen> createState() => _NewPlanInputScreenState();
}

class _NewPlanInputScreenState extends State<NewPlanInputScreen> {
  final _formKey = GlobalKey<FormState>();

  // 입력 값 변수
  String? _selectedAgeGroup;
  Gender? _selectedGender;
  DateTimeRange? _travelDates;
  TimeOfDay? _departureTime;
  TimeOfDay? _arrivalTime;
  int? _numberOfTravelers;
  int? _budget;
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

  // 채팅 화면으로 이동하는 함수
  void _navigateToChatScreen({bool skip = false}) {
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
            'budget': _budget,
            'accommodationLocation': _accommodationLocation,
          };
          print('입력 데이터: $planData');
      } else {
         print('입력 건너뛰기');
      }


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
        // TODO: 기존 디자인 시스템에 맞는 AppBar 스타일 적용
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 나이 입력 -> 연령대 선택으로 변경
                    const Text('연령대', style: TextStyle(fontSize: 16)),
                    Wrap( // 공간에 따라 자동 줄바꿈
                      spacing: 8.0, // 가로 간격
                      runSpacing: 0.0, // 세로 간격
                      children: _ageGroups.map((ageGroup) {
                        return Row(
                          mainAxisSize: MainAxisSize.min, // Row 크기를 내용물에 맞춤
                          children: [
                            Radio<String>(
                              value: ageGroup,
                              groupValue: _selectedAgeGroup,
                              onChanged: (String? value) {
                                setState(() {
                                  _selectedAgeGroup = value;
                                });
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              // TODO: 기존 디자인 시스템 스타일 적용
                            ),
                            InkWell(
                               onTap: () {
                                 setState(() {
                                   _selectedAgeGroup = ageGroup;
                                 });
                               },
                               child: Text(ageGroup)
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16.0),

                    // 성별 선택 (라디오 버튼) - other 제거됨
                    const Text('성별', style: TextStyle(fontSize: 16)),
                    Row(
                      children: Gender.values.expand((gender) {
                        // enum 값을 한글 문자열로 변환
                        String genderText;
                        switch (gender) {
                          case Gender.male:
                            genderText = '남성';
                            break;
                          case Gender.female:
                            genderText = '여성';
                            break;
                        }

                        return [
                          Radio<Gender>(
                            value: gender,
                            groupValue: _selectedGender,
                            onChanged: (Gender? value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            // TODO: 기존 디자인 시스템 스타일 적용
                          ),
                          InkWell(
                            onTap: () {
                               setState(() {
                                 _selectedGender = gender;
                               });
                            },
                            child: Text(genderText) // 수정된 한글 텍스트 사용
                          ),
                          const SizedBox(width: 8),
                        ];
                      }).toList(),
                    ),
                    const SizedBox(height: 16.0),

                    // 여행 기간 선택 (Date Range Picker)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _travelDates == null
                              ? '여행 기간 선택'
                              : '${_travelDates!.start.toString().substring(0, 10)} - ${_travelDates!.end.toString().substring(0, 10)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('선택'),
                          onPressed: () => _selectDateRange(context),
                          // TODO: 기존 디자인 시스템 스타일 적용
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // 왕복 출발-도착 시간 선택 (Time Picker)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('출발 시간', style: TextStyle(fontSize: 16)),
                              TextButton(
                                onPressed: () => _selectTime(context, true),
                                child: Text(_departureTime?.format(context) ?? '선택'),
                                // TODO: 기존 디자인 시스템 스타일 적용
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('도착 시간', style: TextStyle(fontSize: 16)),
                              TextButton(
                                onPressed: () => _selectTime(context, false),
                                child: Text(_arrivalTime?.format(context) ?? '선택'),
                                // TODO: 기존 디자인 시스템 스타일 적용
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // 여행 인원 입력 (숫자 입력 필드)
                    TextFormField(
                      decoration: const InputDecoration(labelText: '여행 인원'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return '여행 인원을 입력해주세요.';
                        if (int.tryParse(value) == null || int.parse(value) <= 0) return '1명 이상 입력해주세요.';
                        return null;
                      },
                      onSaved: (value) => _numberOfTravelers = int.tryParse(value!),
                      // TODO: 기존 디자인 시스템 스타일 적용
                    ),
                    const SizedBox(height: 16.0),

                    // 총 예산 입력 (숫자 입력 필드)
                    TextFormField(
                      decoration: const InputDecoration(labelText: '총 예산 (원)'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return '총 예산을 입력해주세요.';
                        if (int.tryParse(value) == null) return '숫자만 입력해주세요.';
                        return null;
                      },
                      onSaved: (value) => _budget = int.tryParse(value!),
                      // TODO: 기존 디자인 시스템 스타일 적용
                    ),
                    const SizedBox(height: 16.0),

                    // 숙소 위치 입력 (텍스트 입력 필드)
                    TextFormField(
                      decoration: const InputDecoration(labelText: '숙소 위치 (선택사항)'),
                      onSaved: (value) => _accommodationLocation = value,
                      // TODO: 기존 디자인 시스템 스타일 적용
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      persistentFooterButtons: [
        TextButton(
          onPressed: () {
             _navigateToChatScreen(skip: true);
          },
          child: const Text('건너뛰기'),
          // TODO: 기존 디자인 시스템 스타일 적용
        ),
        ElevatedButton(
          onPressed: () {
             // 유효성 검사 및 다음 단계 로직
            final isTextFormValid = _formKey.currentState!.validate(); // 나이 제외 TextFormField 검사
            final isAgeGroupSelected = _selectedAgeGroup != null; // 연령대 선택 확인
            final isGenderSelected = _selectedGender != null;
            final isDatesSelected = _travelDates != null;
            final isDepartureTimeSelected = _departureTime != null;
            final isArrivalTimeSelected = _arrivalTime != null;

            if (isTextFormValid &&
                isAgeGroupSelected && // 연령대 검사 추가
                isGenderSelected &&
                isDatesSelected &&
                isDepartureTimeSelected &&
                isArrivalTimeSelected) {
               // 모든 검사 통과 시 확인 대화 상자 표시 -> 직접 이동으로 변경
               // _showConfirmationDialog(); // 임시 주석 처리
               _navigateToChatScreen();    // 바로 다음 화면으로 이동
            } else {
               // 유효성 검사 실패 시 사용자에게 알림 (예: 스낵바)
               String errorMessage = '필수 항목을 모두 입력해주세요.';
               if (!isAgeGroupSelected) errorMessage = '연령대를 선택해주세요.'; // 연령대 메시지 추가
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
          child: const Text('다음'),
          // TODO: 기존 디자인 시스템 스타일 적용
        ),
      ],
    );
  }
} 