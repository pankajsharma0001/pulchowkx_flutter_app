import 'package:flutter/material.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomAppBar(currentPage: AppPage.events),
      body: Center(child: Text('Events Page')),
    );
  }
}
