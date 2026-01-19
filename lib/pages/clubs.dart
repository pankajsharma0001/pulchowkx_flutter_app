import 'package:flutter/material.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';

class ClubsPage extends StatelessWidget {
  const ClubsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: CustomAppBar(currentPage: AppPage.clubs),
      body: Center(child: Text('Clubs Page')),
    );
  }
}
