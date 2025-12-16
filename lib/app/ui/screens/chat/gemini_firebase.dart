import 'dart:async';
import 'dart:convert';
import 'package:cross_cache/cross_cache.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:wargabut/app/services/gemini_stream_manager.dart';
import 'package:wargabut/app/controller/hive_chat_controller.dart';
import 'package:wargabut/app/ui/screens/chat/WGuideEmptyText.dart';

// Define the shared animation duration
const Duration _kChunkAnimationDuration = Duration(milliseconds: 350);

class WGuidePage extends StatefulWidget {
  const WGuidePage({super.key});

  @override
  WGuidePageState createState() => WGuidePageState();
}

class WGuidePageState extends State<WGuidePage> {
  // Set to `true` to show a "Thinking..." message immediately.
  // Set to `false` to wait for the first chunk before showing the message.
  final bool _isThinkingModel = false;

  final _uuid = const Uuid();
  final _crossCache = CrossCache();
  final _scrollController = ScrollController();
  final _chatController = HiveChatController();

  final _currentUser = const User(id: 'me');
  final _agent = const User(id: 'agent');
  final _systemUser = const User(id: 'system');

  bool _isTyping = false;

  late final GenerativeModel _model;
  late ChatSession _chatSession;

  late final GeminiStreamManager _streamManager;

  // Store scroll state per stream ID
  final Map<String, double> _initialScrollExtents = {};
  final Map<String, bool> _reachedTargetScroll = {};

  // Streaming state management
  StreamSubscription? _currentStreamSubscription;

  final tools = [
    {
      "name": "getEventList",
      "description": "Mengambil daftar event dari Firestore jfestchart.",
      "parameters": {
        "type": "object",
        "properties": {
          "month": {
            "type": "string",
            "description": "Filter bulan, misalnya 'September 2025'. Opsional."
          }
        }
      }
    },
    {
      "name": "getEventDetail",
      "description": "Mengambil detail satu event berdasarkan ID Firestore.",
      "parameters": {
        "type": "object",
        "properties": {
          "eventId": {
            "type": "string",
            "description": "ID dokumen Firestore."
          }
        },
        "required": ["eventId"]
      }
    }
  ];

  final getEventListTool = FunctionDeclaration(
    'getEventList',
    'Ambil daftar seluruh event dari Firestore collection jfestchart.',
    parameters: {},
  );

  final getEventDetailTool = FunctionDeclaration(
    'getEventDetail',
    'Ambil detail satu event berdasarkan Firestore document ID.',
    parameters: {
      'eventId': Schema.string(
        description: 'ID dokumen event di Firestore collection jfestchart.',
      ),
    },
  );


  @override
  void initState() {
    super.initState();
    _activateFirebaseAppCheck();
    _streamManager = GeminiStreamManager(
      chatController: _chatController,
      chunkAnimationDuration: _kChunkAnimationDuration,
    );

    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-pro',
      tools: [
        Tool.googleSearch(),
        Tool.functionDeclarations([
          getEventListTool,
          getEventDetailTool,
        ]),
      ],
    );
    _chatSession = _model.startChat(
      history: _chatController.messages
          .whereType<TextMessage>()
          .map((message) => Content.text(message.text))
          .toList(),
    );
  }

  @override
  void dispose() {
    _currentStreamSubscription?.cancel();
    _streamManager.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _crossCache.dispose();
    super.dispose();
  }

  Future<dynamic> handleFunctionCall(String fn, Map<String, dynamic>? args) async {
    switch (fn) {

      case "getEventList":
        return await _getEventList(args);

      case "getEventDetail":
        return await _getEventDetail(args);

      default:
        return {"error": "Function not implemented"};
    }
  }

  Future<dynamic> _handleFunctionCall(FunctionCall fc) async {
    switch (fc.name) {
      case "getEventList":
        return await _getEventList(fc.args);

      case "getEventDetail":
        return await _getEventDetail(fc.args);

      default:
        return {"error": "Unknown function: ${fc.name}"};
    }
  }

  Future<List<Map<String, dynamic>>> _getEventList(Map<String, dynamic>? args) async {
    final month = args?["month"];
    final snapshot = await FirebaseFirestore.instance
        .collection("jfestchart")
        .orderBy("date")
        .get();

    final events = snapshot.docs.map((doc) {
      final data = doc.data();
      data["id"] = doc.id;
      return data;
    }).toList();

    if (month != null) {
      return events.where((e) {
        return (e["date"] ?? "").toString().contains(month);
      }).toList();
    }

    return events;
  }

  Future<Map<String, dynamic>> _getEventDetail(Map<String, dynamic>? args) async {
    final id = args?["eventId"];
    if (id == null) return {"error": "eventId is required"};

    final doc = await FirebaseFirestore.instance
        .collection("jfestchart")
        .doc(id)
        .get();

    if (!doc.exists) return {"error": "Event not found"};

    final data = doc.data()!;
    data["id"] = doc.id;
    return data;
  }

  Future<void> _afterFunctionFollowUp(GenerateContentResponse followUp) async {
    final text = followUp.text;

    if (text != null && text.isNotEmpty) {
      final message = TextMessage(
        id: _uuid.v4(),
        authorId: _agent.id,
        createdAt: DateTime.now().toUtc(),
        text: text,
      );

      await _chatController.insertMessage(message);
    }
  }

  void _activateFirebaseAppCheck() async {
    if (kIsWeb) {
      try {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('6LfDTa0rAAAAALTcuZKv-tNYuGaRrQQUZCyj805b'),
        );
        if (kDebugMode) {
          print('Firebase App Check activated successfully for web.');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error activating Firebase App Check for web: $e');
        }
      }
    }
  }

  void _handleStreamError(
      String streamId,
      dynamic error,
      TextStreamMessage? streamMessage,
      ) async {
    debugPrint('Generation error for $streamId: $error');

    // Stream failed (only if message was created)
    if (streamMessage != null) {
      await _streamManager.errorStream(streamId, error);
    }

    // Reset streaming state
    if (mounted) {
      setState(() {
      });
    }
    _currentStreamSubscription = null;

    // Clean up scroll state for this stream ID
    _initialScrollExtents.remove(streamId);
    _reachedTargetScroll.remove(streamId);
  }

  Future<void> _toggleTyping() async {
    if (!_isTyping) {
      await _chatController.insertMessage(
        CustomMessage(
          id: _uuid.v4(),
          authorId: _systemUser.id,
          metadata: {'type': 'typing'},
          createdAt: DateTime.now().toUtc(),
        ),
      );
      _isTyping = true;
    } else {
      try {
        final typingMessage = _chatController.messages.firstWhere(
              (message) => message.metadata?['type'] == 'typing',
        );

        await _chatController.removeMessage(typingMessage);
        _isTyping = false;
      } catch (e) {
        _isTyping = false;
        await _toggleTyping();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WGuide'),
              Text(
                'tips event jejepangan',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
                ),
              ),
            ],
          ),
          // leading: IconButton(
          //   icon: const Icon(Icons.arrow_back),
          //   onPressed: () {
          //     Navigator.pop(context);
          //   },
          // ),
          actions: [
            _chatController.messages.isNotEmpty ?
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _chatController.setMessages([]);
                _chatSession = _model.startChat();
              },
            ) : const SizedBox.shrink(),
          ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
      body: ChangeNotifierProvider.value(
        value: _streamManager,
        child: Chat(
          builders: Builders(
            chatAnimatedListBuilder: (context, itemBuilder) {
              return ChatAnimatedList(
                scrollController: _scrollController,
                itemBuilder: itemBuilder,
                shouldScrollToEndWhenAtBottom: false,
              );
            },
            emptyChatListBuilder: (context) => const WGuideEmptyText(),
            customMessageBuilder:
                (
                context,
                message,
                index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? ChatColors.dark().surfaceContainer
                    : ChatColors.light().surfaceContainer,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: const IsTypingIndicator(),
            ),
            imageMessageBuilder:
                (
                context,
                message,
                index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) => FlyerChatImageMessage(
              message: message,
              index: index,
              showTime: false,
              showStatus: false,
            ),
            textMessageBuilder:
                (
                context,
                message,
                index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) => FlyerChatTextMessage(
              message: message,
              index: index,
              // showTime: false,
              // showStatus: false,
              // receivedBackgroundColor: Colors.transparent,
              // padding: message.authorId == _agent.id
              //     ? EdgeInsets.zero
              //     : const EdgeInsets.symmetric(
              //   horizontal: 16,
              //   vertical: 10,
              // ),
            ),
            textStreamMessageBuilder:
                (
                context,
                message,
                index, {
              required bool isSentByMe,
              MessageGroupStatus? groupStatus,
            }) {
              // Watch the manager for state updates
              final streamState = context
                  .watch<GeminiStreamManager>()
                  .getState(message.streamId);
              // Return the stream message widget, passing the state
              return FlyerChatTextStreamMessage(
                message: message,
                index: index,
                streamState: streamState,
                chunkAnimationDuration: _kChunkAnimationDuration,
                // showTime: false,
                // showStatus: false,
                // receivedBackgroundColor: Colors.transparent,
                // padding: message.authorId == _agent.id
                //     ? EdgeInsets.zero
                //     : const EdgeInsets.symmetric(
                //   horizontal: 16,
                //   vertical: 10,
                // ),
              );
            },
          ),
          chatController: _chatController,
          crossCache: _crossCache,
          currentUserId: _currentUser.id,
          // onAttachmentTap: _handleAttachmentTap,
          onMessageSend: _handleMessageSend,
          resolveUser: (id) => Future.value(switch (id) {
            'me' => _currentUser,
            'agent' => _agent,
            'system' => _systemUser,
            _ => null,
          }),
          theme: theme.brightness == Brightness.dark
              ? ChatTheme.dark()
              : ChatTheme.light(),
        ),
      ),
    );
  }

  void _handleMessageSend(String text) async {
    await _chatController.insertMessage(
      TextMessage(
        id: _uuid.v4(),
        authorId: _currentUser.id,
        createdAt: DateTime.now().toUtc(),
        text: text,
        metadata: isOnlyEmoji(text) ? {'isOnlyEmoji': true} : null,
      ),
    );

    final content = Content.text(text);
    _toggleTyping();
    _sendContent(content);
  }

  void _sendContent(Content content) async {
    // Generate a unique ID for the stream
    final streamId = _uuid.v4();
    TextStreamMessage? streamMessage;
    Timer? thinkingTimer;

    // A flag to ensure the message is created only once.
    var messageInserted = false;

    // Store scroll state per stream ID
    _reachedTargetScroll[streamId] = false;

    // Set streaming state
    setState(() {
    });

    // Helper to create and insert the message, ensuring it only happens once.
    Future<void> createAndInsertMessage() async {
      if (messageInserted || !mounted) return;
      messageInserted = true;
      _toggleTyping();

      // If the timer is still active, we beat it. Cancel it.
      thinkingTimer?.cancel();

      streamMessage = TextStreamMessage(
        id: streamId,
        authorId: _agent.id,
        createdAt: DateTime.now().toUtc(),
        streamId: streamId,
      );
      await _chatController.insertMessage(streamMessage!);
      _streamManager.startStream(streamId, streamMessage!);
    }

    if (_isThinkingModel) {
      // For thinking models, schedule the message insertion after a delay.
      thinkingTimer = Timer(const Duration(milliseconds: 300), () async {
        await createAndInsertMessage();
        // When timer fires, message is inserted, scroll to the bottom.
        // This is needed because we use shouldScrollToEndWhenAtBottom: false,
        // due to custom scroll logic below, so we must also scroll to the
        // thinking label manually.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!_scrollController.hasClients || !mounted) return;
          await _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.linearToEaseOut,
          );
        });
      });
    }

    try {
      final response = _chatSession.sendMessageStream(content);

      // Create a stream subscription that can be cancelled
      _currentStreamSubscription = response.listen(
            (chunk) async {
              // =======================================
              //   FUNCTION CALLING HANDLER
              // =======================================
              // if (chunk.functionCalls.isNotEmpty) {
              //   final call = chunk.functionCalls.first;
              //
              //   // STOP streaming text
              //   await _currentStreamSubscription?.cancel();
              //
              //   final result = await _handleFunctionCall(call);
              //
              //   // Kirim balik hasil function ke model
              //   final followUp = await _chatSession.sendMessage(
              //     Content.functionResponse(call.name, result),
              //   );
              //
              //   // Setelah itu, kirim follow-up message ke UI
              //   await _afterFunctionFollowUp(followUp);
              //
              //   return;
              // }
// =======================================
              if (chunk.text != null) {
            final textChunk = chunk.text!;
            if (textChunk.isEmpty) return; // Skip empty chunks

            // On the first valid chunk, ensure the message is inserted.
            // This handles both non-thinking models and thinking models where
            // the response arrives before the timer.
            if (!messageInserted) {
              await createAndInsertMessage();
            }

            // Ensure stream message exists before adding chunk
            if (streamMessage == null) return;

            // Send chunk to the manager - this triggers notifyListeners
            _streamManager.addChunk(streamId, textChunk);

            // Schedule scroll check after the frame rebuilds
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollController.hasClients || !mounted) return;

              // Retrieve state for this specific stream
              var initialExtent = _initialScrollExtents[streamId];
              final reachedTarget = _reachedTargetScroll[streamId] ?? false;

              if (reachedTarget) return; // Already scrolled to target

              // Store initial extent after first chunk caused rebuild
              initialExtent ??= _initialScrollExtents[streamId] =
                  _scrollController.position.maxScrollExtent;

              // Only scroll if the list is scrollable
              if (initialExtent > 0) {
                // Calculate target scroll position (copied from original logic)
                final targetScroll =
                    initialExtent + // Use the stored initial extent
                        _scrollController.position.viewportDimension -
                        MediaQuery.of(context).padding.bottom -
                        168; // height of the composer + height of the app bar + visual buffer of 8

                if (_scrollController.position.maxScrollExtent > targetScroll) {
                  _scrollController.animateTo(
                    targetScroll,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.linearToEaseOut,
                  );
                  // Mark that we've reached the target for this stream
                  _reachedTargetScroll[streamId] = true;
                } else {
                  // If we haven't reached target position yet, scroll to bottom
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.linearToEaseOut,
                  );
                }
              }
            });
          }
        },
        onDone: () async {
          thinkingTimer?.cancel();
          // Stream completed successfully (only if message was created)
          if (streamMessage != null) {
            await _streamManager.completeStream(streamId);
          }

          // Reset streaming state
          if (mounted) {
            setState(() {
            });
          }
          _currentStreamSubscription = null;

          // Clean up scroll state for this stream ID
          _initialScrollExtents.remove(streamId);
          _reachedTargetScroll.remove(streamId);
        },
        onError: (error) async {
          _toggleTyping();
          thinkingTimer?.cancel();
          _handleStreamError(streamId, error, streamMessage);
        },
      );
    } catch (error) {
      _toggleTyping();
      thinkingTimer?.cancel();
      // Catch other potential errors during stream processing
      _handleStreamError(streamId, error, streamMessage);
    }
  }
}

class CustomComposer extends StatefulWidget {
  final Widget? topWidget;
  final bool isStreaming;
  final VoidCallback? onStop;

  const CustomComposer({
    super.key,
    this.topWidget,
    this.isStreaming = false,
    this.onStop,
  });

  @override
  State<CustomComposer> createState() => _CustomComposerState();
}

class _CustomComposerState extends State<CustomComposer> {
  final _key = GlobalKey();
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.onKeyEvent = _handleKeyEvent;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Check for Shift+Enter
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isShiftPressed) {
      _handleSubmitted(_textController.text);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant CustomComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final onAttachmentTap = context.read<OnAttachmentTapCallback?>();
    final theme = context.select(
          (ChatTheme t) => (
      bodyMedium: t.typography.bodyMedium,
      onSurface: t.colors.onSurface,
      surfaceContainerHigh: t.colors.surfaceContainerHigh,
      surfaceContainerLow: t.colors.surfaceContainerLow,
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: Container(
          key: _key,
          color: theme.surfaceContainerLow,
          child: Column(
            children: [
              if (widget.topWidget != null) widget.topWidget!,
              Padding(
                padding: EdgeInsets.only(
                  bottom: bottomSafeArea,
                ).add(const EdgeInsets.all(8.0)),
                child: Row(
                  children: [
                    onAttachmentTap != null
                        ? IconButton(
                      icon: const Icon(Icons.attachment),
                      color: theme.onSurface.withValues(alpha: 0.5),
                      onPressed: onAttachmentTap,
                    )
                        : const SizedBox.shrink(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          hintStyle: theme.bodyMedium.copyWith(
                            color: theme.onSurface.withValues(alpha: 0.5),
                          ),
                          border: const OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          filled: true,
                          fillColor: theme.surfaceContainerHigh.withValues(
                            alpha: 0.8,
                          ),
                          hoverColor: Colors.transparent,
                        ),
                        style: theme.bodyMedium.copyWith(
                          color: theme.onSurface,
                        ),
                        onSubmitted: _handleSubmitted,
                        textInputAction: TextInputAction.newline,
                        autocorrect: true,
                        autofocus: false,
                        textCapitalization: TextCapitalization.sentences,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: widget.isStreaming
                          ? const Icon(Icons.stop_circle)
                          : const Icon(Icons.send),
                      color: theme.onSurface.withValues(alpha: 0.5),
                      onPressed: widget.isStreaming
                          ? widget.onStop
                          : () => _handleSubmitted(_textController.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _measure() {
    if (!mounted) return;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final height = renderBox.size.height;
      final bottomSafeArea = MediaQuery.of(context).padding.bottom;

      context.read<ComposerHeightNotifier>().setHeight(height - bottomSafeArea);
    }
  }

  void _handleSubmitted(String text) {
    if (text.isNotEmpty) {
      context.read<OnMessageSendCallback?>()?.call(text);
      _textController.clear();
    }
  }
}
