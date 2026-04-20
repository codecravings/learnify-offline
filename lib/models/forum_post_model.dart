class ForumSolution {
  final String id;
  final String content;
  final String authorId;
  final String authorUsername;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;
  final bool isAccepted;

  const ForumSolution({
    required this.id,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    this.upvotes = 0,
    this.downvotes = 0,
    required this.createdAt,
    this.isAccepted = false,
  });

  factory ForumSolution.fromJson(Map<String, dynamic> json) {
    return ForumSolution(
      id: json['id'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      authorUsername: json['authorUsername'] as String,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isAccepted: json['isAccepted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': createdAt.toIso8601String(),
      'isAccepted': isAccepted,
    };
  }

  ForumSolution copyWith({
    String? id,
    String? content,
    String? authorId,
    String? authorUsername,
    int? upvotes,
    int? downvotes,
    DateTime? createdAt,
    bool? isAccepted,
  }) {
    return ForumSolution(
      id: id ?? this.id,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      createdAt: createdAt ?? this.createdAt,
      isAccepted: isAccepted ?? this.isAccepted,
    );
  }

  int get score => upvotes - downvotes;

  @override
  String toString() => 'ForumSolution(id: $id, authorUsername: $authorUsername, isAccepted: $isAccepted)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ForumSolution && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ForumPostModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorUsername;
  final List<String> tags;
  final String category;
  final int upvotes;
  final int downvotes;
  final List<ForumSolution> solutions;
  final DateTime createdAt;
  final bool isResolved;
  final String? bestSolutionId;

  const ForumPostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    this.tags = const [],
    this.category = 'general',
    this.upvotes = 0,
    this.downvotes = 0,
    this.solutions = const [],
    required this.createdAt,
    this.isResolved = false,
    this.bestSolutionId,
  });

  factory ForumPostModel.fromJson(Map<String, dynamic> json) {
    // Handle date parsing from both ISO strings and Firestore Timestamps
    DateTime parseDate(dynamic val) {
      if (val is String) return DateTime.parse(val);
      if (val is DateTime) return val;
      return DateTime.now();
    }

    return ForumPostModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorUsername: (json['authorUsername'] ?? json['authorName'] ?? '') as String,
      tags: List<String>.from(json['tags'] ?? []),
      category: json['category'] as String? ?? 'general',
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      solutions: (json['solutions'] as List<dynamic>?)
              ?.map((e) => ForumSolution.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: parseDate(json['createdAt']),
      isResolved: json['isResolved'] as bool? ?? false,
      bestSolutionId: (json['bestSolutionId'] ?? json['acceptedSolutionId']) as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'authorName': authorUsername, // compat alias
      'tags': tags,
      'category': category,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'solutionCount': solutions.length,
      'solutions': solutions.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isResolved': isResolved,
      'bestSolutionId': bestSolutionId,
      'acceptedSolutionId': bestSolutionId, // compat alias
    };
  }

  ForumPostModel copyWith({
    String? id,
    String? title,
    String? content,
    String? authorId,
    String? authorUsername,
    List<String>? tags,
    String? category,
    int? upvotes,
    int? downvotes,
    List<ForumSolution>? solutions,
    DateTime? createdAt,
    bool? isResolved,
    String? bestSolutionId,
  }) {
    return ForumPostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      solutions: solutions ?? this.solutions,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
      bestSolutionId: bestSolutionId ?? this.bestSolutionId,
    );
  }

  int get score => upvotes - downvotes;
  int get solutionCount => solutions.length;

  @override
  String toString() => 'ForumPostModel(id: $id, title: $title, isResolved: $isResolved)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ForumPostModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
