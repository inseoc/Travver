import 'package:flutter/material.dart';
import 'new_plan_input_screen.dart'; // 새 플랜 입력 화면 import

class AiConsultantScreen extends StatelessWidget {
  const AiConsultantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: 기존 여행 플랜 데이터 가져오기 (임시 데이터 사용)
    final List<String> existingPlans = List.generate(5, (index) => '기존 여행 플랜 ${index + 1}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 여행 컨설턴트'),
        // TODO: 기존 디자인 시스템에 맞는 AppBar 스타일 적용
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('새 여행 플랜 만들기'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewPlanInputScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 18),
                // TODO: 기존 디자인 시스템에 맞는 버튼 스타일 적용
              ),
            ),
            const SizedBox(height: 24.0),
            const Text(
              '나의 여행 플랜',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              // TODO: 기존 디자인 시스템에 맞는 텍스트 스타일 적용
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: ListView.builder(
                itemCount: existingPlans.length,
                itemBuilder: (context, index) {
                  return Card(
                    // TODO: 기존 디자인 시스템에 맞는 카드 스타일 적용
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Text(existingPlans[index]),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // TODO: 기존 플랜 상세 화면으로 이동하는 로직 구현
                        print('${existingPlans[index]} 선택됨');
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 