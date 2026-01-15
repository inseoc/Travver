import 'package:equatable/equatable.dart';

/// 채팅 메시지 역할
enum MessageRole {
  user,
  assistant,
  system,
}

/// 메시지 상태
enum MessageStatus {
  sending,
  sent,
  error,
}

/// 채팅 메시지 모델
class ChatMessage extends Equatable {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isToolCall;
  final String? toolName;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.isToolCall = false,
    this.toolName,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  factory ChatMessage.user({
    required String id,
    required String content,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.user,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  factory ChatMessage.assistant({
    required String id,
    required String content,
    DateTime? timestamp,
    bool isToolCall = false,
    String? toolName,
  }) {
    return ChatMessage(
      id: id,
      role: MessageRole.assistant,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      isToolCall: isToolCall,
      toolName: toolName,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: MessageRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      isToolCall: json['is_tool_call'] as bool? ?? false,
      toolName: json['tool_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'is_tool_call': isToolCall,
      'tool_name': toolName,
    };
  }

  ChatMessage copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isToolCall,
    String? toolName,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isToolCall: isToolCall ?? this.isToolCall,
      toolName: toolName ?? this.toolName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        role,
        content,
        timestamp,
        status,
        isToolCall,
        toolName,
      ];
}
