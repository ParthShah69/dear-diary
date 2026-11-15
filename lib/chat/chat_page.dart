import 'package:material_ui/material_ui.dart';

import 'cloud_chat_page.dart';

/// Signed-in, Supabase-backed direct message experience.
class ChatPage extends StatelessWidget {
  final VoidCallback onInstantLock;
  // Kept for compatibility with the previous prototype's constructor.
  final String storageScope;

  const ChatPage({
    super.key,
    required this.onInstantLock,
    required this.storageScope,
  });

  @override
  Widget build(BuildContext context) =>
      CloudChatPage(onInstantLock: onInstantLock);
}
