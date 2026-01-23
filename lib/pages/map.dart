import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/widgets/chat_bot_widget.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://pulchowk-x.vercel.app/map?embed=true'));
  }

  /// Handle locations returned from the chatbot
  void _handleChatBotLocations(List<ChatBotLocation> locations, String action) {
    if (locations.isEmpty) return;

    // For now, this just keeps the callback structure valid
    debugPrint("Chatbot requested action: $action at $locations");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.map),
      body: Stack(
        children: [
          // WebView Map
          WebViewWidget(controller: _controller),

          // Chatbot Widget Overlay
          ChatBotWidget(onLocationsReturned: _handleChatBotLocations),
        ],
      ),
    );
  }
}
