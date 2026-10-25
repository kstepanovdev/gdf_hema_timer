import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../widgets/settings_drawer.dart';
import 'opossum_setup_page.dart';
import 'score_page.dart';

class ModeSelectionPage extends StatelessWidget {
  const ModeSelectionPage({super.key, this.opossumSetupBuilder});
  final WidgetBuilder? opossumSetupBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      drawer: const SettingsDrawer(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                key: const Key('standalone-mode'),
                leading: const Icon(Icons.timer_outlined),
                title: Text(l10n.standaloneMode),
                subtitle: Text(l10n.standaloneDescription),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ScorePage()),
                ),
              ),
            ),
            Card(
              child: ListTile(
                key: const Key('opossum-mode'),
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(l10n.tournamentMode),
                subtitle: Text(l10n.tournamentDescription),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        opossumSetupBuilder ?? (_) => const OpossumSetupPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
