import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp_assist/models/chat_message_model.dart';
import 'package:fyp_assist/models/user_model.dart';
import 'package:fyp_assist/services/firestore_service.dart';
import 'package:intl/intl.dart';

class ChatTab extends ConsumerStatefulWidget {
  final String projectId;
  const ChatTab({super.key, required this.projectId});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(UserModel currentUser) async {
    if (_messageController.text.trim().isEmpty) {
      return; // Don't send empty messages
    }

    final text = _messageController.text.trim();
    // Clear the text field immediately
    _messageController.clear();

    // Store context-dependent objects before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(firestoreServiceProvider).sendChatMessage(
        projectId: widget.projectId,
        text: text,
        senderId: currentUser.uid,
        senderName: currentUser.name,
      );
    } catch (e) {
      // If sending fails, put the text back so the user can retry
      _messageController.text = text;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatAsyncValue = ref.watch(chatStreamProvider(widget.projectId));
    final currentUser = ref.watch(userDataProvider).value;

    return Column(
      children: [
        // --- CHAT MESSAGES LIST ---
        Expanded(
          child: chatAsyncValue.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(child: Text('Be the first to say hello!'));
              }
              return ListView.builder(
                reverse: true, // Shows newest messages at the bottom
                itemCount: messages.length,
                itemBuilder: (ctx, index) {
                  final message = messages[index];
                  final isMe = message.senderId == currentUser?.uid;

                  return _buildMessageBubble(message, isMe);
                },
              );
            },
            error: (err, stack) =>
                Center(child: Text('Error: ${err.toString()}')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),

        // --- TEXT INPUT FIELD ---
        if (currentUser != null) // Only show input if user is loaded
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration:
                    const InputDecoration(labelText: 'Send a message...'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendMessage(currentUser),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper widget to build the chat bubble
  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        elevation: 2,
        color: isMe ? Theme.of(context).primaryColorLight : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                isMe ? 'You' : message.senderName, // Show 'You' for my messages
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(message.text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(message.timestamp.toDate()), // '5:08 PM'
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}