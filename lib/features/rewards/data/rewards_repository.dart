import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';

class Reward {
  const Reward({required this.id, required this.title, required this.pointCost, required this.active});

  final String id;
  final String title;
  final int pointCost;
  final bool active;

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        id: json['id'] as String,
        title: json['title'] as String,
        pointCost: json['point_cost'] as int,
        active: json['active'] as bool? ?? true,
      );
}

class LedgerEntry {
  const LedgerEntry({required this.points, required this.reason, required this.createdAt});

  final int points;
  final String reason;
  final DateTime createdAt;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        points: json['points'] as int,
        reason: json['reason'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

class RewardsRepository {
  RewardsRepository(this._client);

  final SupabaseClient _client;

  Future<List<Reward>> store() async {
    final rows =
        await _client.from('rewards').select().eq('active', true).order('point_cost');
    return (rows as List).map((r) => Reward.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<LedgerEntry>> ledger(String userId) async {
    final rows = await _client
        .from('reward_ledger')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List).map((r) => LedgerEntry.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<int> balance(String userId) async {
    final entries = await ledger(userId);
    return entries.fold<int>(0, (sum, e) => sum + e.points);
  }

  Future<Reward> createReward({
    required String familyId,
    required String createdBy,
    required String title,
    required int pointCost,
  }) async {
    final row = await _client
        .from('rewards')
        .insert({
          'family_id': familyId,
          'created_by': createdBy,
          'title': title,
          'point_cost': pointCost,
        })
        .select()
        .single();
    return Reward.fromJson(row);
  }

  /// Child requests a redemption; a parent approves it, which is when the
  /// ledger debit happens (approval-gated economy, product spec §12).
  Future<void> requestRedemption({required String rewardId, required String userId}) async {
    await _client.from('redemptions').insert({'reward_id': rewardId, 'user_id': userId});
  }

  Future<List<Map<String, dynamic>>> pendingRedemptions() async {
    final rows = await _client
        .from('redemptions')
        .select('id, user_id, status, rewards(id, title, point_cost, family_id)')
        .eq('status', 'pending');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> approveRedemption({
    required Map<String, dynamic> redemption,
    required String parentId,
  }) async {
    final reward = redemption['rewards'] as Map<String, dynamic>;
    await _client.from('redemptions').update({
      'status': 'approved',
      'approved_by': parentId,
    }).eq('id', redemption['id'] as String);
    await _client.from('reward_ledger').insert({
      'family_id': reward['family_id'],
      'user_id': redemption['user_id'],
      'points': -(reward['point_cost'] as int),
      'reason': 'Redeemed: ${reward['title']}',
      'related_type': 'redemption',
      'related_id': redemption['id'],
    });
  }
}

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) => RewardsRepository(supabase));

final rewardStoreProvider = FutureProvider<List<Reward>>((ref) async {
  return ref.watch(rewardsRepositoryProvider).store();
});
