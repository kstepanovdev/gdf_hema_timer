import 'package:flutter/material.dart';
import '../../l10n/gen/app_localizations.dart';
import 'fight_event_formatter.dart';
import 'fight_log.dart';

class FightLogView {
  static void show(BuildContext context, FightLog fightLog) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final events = fightLog.events;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: fightLog.isEmpty
              ? Center(
                  child: Text(
                    l10n.noEventsYet,
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        formatFightEvent(events[index], l10n),
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
