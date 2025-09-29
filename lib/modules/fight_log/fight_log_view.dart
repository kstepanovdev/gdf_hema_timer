import 'package:flutter/material.dart';
import 'fight_log.dart';

class FightLogView {
  static void show(BuildContext context, FightLog fightLog) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: fightLog.isEmpty
              ? const Center(
                  child: Text("No events yet", style: TextStyle(fontSize: 16)),
                )
              : ListView.builder(
                  itemCount: fightLog.events.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        fightLog.events[index],
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
