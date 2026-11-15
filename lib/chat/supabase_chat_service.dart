import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPair {
  final String id;
  final String peerId;
  final String peerUsername;
  const ChatPair(this.id, this.peerId, this.peerUsername);
}

class SupabaseChatService {
  final SupabaseClient client;
  SupabaseChatService(this.client);

  String get userId => client.auth.currentUser!.id;

  Future<String?> username() async {
    final row = await client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    return row?['username'] as String?;
  }

  Future<void> ensureUsername(String value) async {
    await client.rpc('set_username', params: {'p_username': value});
  }

  Future<void> sendRequest(String username) async {
    await client.rpc('send_friend_request', params: {'p_username': username});
  }

  Future<void> respond(String requestId, bool accept) async {
    await client.rpc(
      'respond_friend_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
  }

  Future<void> unfriend(String peerId) async {
    await client.rpc('end_friendship', params: {'p_other_user_id': peerId});
  }

  Future<List<Map<String, dynamic>>> requests() async {
    final result = await client
        .from('friend_requests')
        .select(
          'id,requester_id,recipient_id,status,created_at,requester:profiles!friend_requests_requester_id_fkey(username),recipient:profiles!friend_requests_recipient_id_fkey(username)',
        )
        .or('requester_id.eq.$userId,recipient_id.eq.$userId')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<List<ChatPair>> conversations() async {
    final memberRows = await client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', userId);
    final ids = List<Map<String, dynamic>>.from(memberRows)
        .map((row) => row['conversation_id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    final rows = await client
        .from('conversations')
        .select('id,user_low,user_high')
        .inFilter('id', ids);
    final conversations = List<Map<String, dynamic>>.from(rows);
    final peerIds = conversations
        .map(
          (row) =>
              row['user_low'] == userId ? row['user_high'] : row['user_low'],
        )
        .cast<String>()
        .toSet()
        .toList();
    if (peerIds.isEmpty) return [];
    final profileRows = await client
        .from('profiles')
        .select('id,username')
        .inFilter('id', peerIds);
    final names = {
      for (final row in List<Map<String, dynamic>>.from(profileRows))
        row['id'] as String: row['username'] as String,
    };
    return conversations.map((row) {
      final peer = row['user_low'] == userId
          ? row['user_high'] as String
          : row['user_low'] as String;
      return ChatPair(row['id'] as String, peer, names[peer] ?? 'Friend');
    }).toList();
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final rows = await client
        .from('messages')
        .select('id,conversation_id,sender_id,body,sent_at')
        .eq('conversation_id', conversationId)
        .order('sent_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String body,
  ) async {
    final id = _uuidV4();
    final result = await client.rpc(
      'send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_client_message_id': id,
        'p_body': body,
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> acknowledge(String messageId, {required bool read}) async {
    await client.rpc(
      'acknowledge_message',
      params: {'p_message_id': messageId, 'p_read': read},
    );
  }

  Future<Map<String, Map<String, dynamic>>> receipts(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};
    final rows = await client
        .from('message_receipts')
        .select('message_id,user_id,delivered_at,read_at')
        .inFilter('message_id', messageIds);
    return {
      for (final row in List<Map<String, dynamic>>.from(rows))
        row['message_id'] as String: row,
    };
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
