/// One unsent / unverified submission in the offline queue.
/// Stored locally as JSON. Sent ONE at a time, in order, single POST only.
/// NEVER delete a queued item silently — it is removed only after the
/// sheet verification confirms the row landed.
class PendingItem {
  final String id; // unique: type + username + timestamp
  final String type; // location | leave | dailyReport | zeroEntry
  final Map<String, dynamic> payload;
  final String createdAtIso;
  final int attempts;

  const PendingItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAtIso,
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'createdAtIso': createdAtIso,
        'attempts': attempts,
      };

  factory PendingItem.fromJson(Map<String, dynamic> j) => PendingItem(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        payload: Map<String, dynamic>.from(j['payload'] ?? {}),
        createdAtIso: (j['createdAtIso'] ?? '').toString(),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );

  PendingItem withAttempt() => PendingItem(
        id: id,
        type: type,
        payload: payload,
        createdAtIso: createdAtIso,
        attempts: attempts + 1,
      );
}
