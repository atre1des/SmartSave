/// Represents a message in the AI conversation.
class AIMessage {
  const AIMessage({
    required this.role,
    required this.content,
    this.timestamp,
    this.isStreaming = false,
    this.isLocalFallback = false,
    this.error,
  });

  /// Role of the message: 'user', 'assistant', or 'system'
  final String role;

  /// Message content
  final String content;

  /// When the message was created
  final DateTime? timestamp;

  /// Whether the assistant message is still streaming
  final bool isStreaming;

  /// True for a reply generated locally while the proxy was unreachable.
  final bool isLocalFallback;

  /// Error message if the request failed
  final String? error;

  /// Convenience getter for backward compatibility
  bool get isUser => role == 'user';

  /// Convenience getter for backward compatibility
  String get text => content;

  factory AIMessage.user(String content) =>
      AIMessage(role: 'user', content: content, timestamp: DateTime.now());

  factory AIMessage.assistant(
    String content, {
    bool isStreaming = false,
    bool isLocalFallback = false,
    String? error,
  }) => AIMessage(
    role: 'assistant',
    content: content,
    timestamp: DateTime.now(),
    isStreaming: isStreaming,
    isLocalFallback: isLocalFallback,
    error: error,
  );

  factory AIMessage.system(String content) =>
      AIMessage(role: 'system', content: content, timestamp: DateTime.now());

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp?.toIso8601String(),
    'isStreaming': isStreaming,
    'isLocalFallback': isLocalFallback,
    'error': error,
  };

  /// Converts to a Map for SQLite storage
  Map<String, Object?> toMap() => {
    'role': role,
    'content': content,
    'timestamp':
        timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
    'is_streaming': isStreaming ? 1 : 0,
    'error': error,
  };

  /// Creates from a SQLite row Map
  factory AIMessage.fromMap(Map<String, Object?> map) => AIMessage(
    role: map['role'] as String,
    content: map['content'] as String,
    timestamp: map['timestamp'] != null
        ? DateTime.parse(map['timestamp'] as String)
        : null,
    isStreaming: (map['is_streaming'] as int? ?? 0) == 1,
    error: map['error'] as String?,
  );

  factory AIMessage.fromJson(Map<String, dynamic> json) => AIMessage(
    role: json['role'] as String? ?? '',
    content: (json['content'] ?? json['text']) as String? ?? '',
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String)
        : null,
    isStreaming: json['isStreaming'] as bool? ?? false,
    isLocalFallback: json['isLocalFallback'] as bool? ?? false,
    error: json['error'] as String?,
  );

  AIMessage copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
    bool? isLocalFallback,
    String? error,
  }) => AIMessage(
    role: role ?? this.role,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    isStreaming: isStreaming ?? this.isStreaming,
    isLocalFallback: isLocalFallback ?? this.isLocalFallback,
    error: error ?? this.error,
  );
}

/// Conversation modes for the assistant
enum AssistantMode {
  /// Beginner mode - explains concepts, asks clarifying questions
  beginner,

  /// Experienced mode - concise, analytical
  experienced,
}

/// Quick action types for the assistant
enum QuickActionType {
  /// Help reach a savings goal
  savingsGoal,

  /// Explain an investment opportunity
  explainOpportunity,

  /// Compare deposit and shares
  compareDepositShares,

  /// Analyze portfolio
  analyzePortfolio,

  /// Explore IPO
  exploreIPO,

  /// What-if scenario
  whatIfScenario,
}

/// Represents a quick action suggestion
class QuickAction {
  const QuickAction({
    required this.type,
    required this.title,
    required this.description,
    this.prefillPrompt,
  });

  final QuickActionType type;
  final String title;
  final String description;
  final String? prefillPrompt;
}
