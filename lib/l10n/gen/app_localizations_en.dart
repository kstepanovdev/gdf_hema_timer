// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Scoreboard';

  @override
  String get reset => 'Reset';

  @override
  String get start => 'START';

  @override
  String get stop => 'Stop';

  @override
  String get warning => 'Warning';

  @override
  String get caution => 'Caution';

  @override
  String get double => 'Double';

  @override
  String get helpTitle => 'How to use';

  @override
  String get helpTap => 'Tap a number to add a point.';

  @override
  String get helpLongPress => 'Long-press a number to remove a point.';

  @override
  String get helpTimer => 'Long-press the timer to change the round time.';

  @override
  String get helpLog => 'Drag the log bar up to open the fight log.';

  @override
  String get helpResetScore =>
      'Long-press Reset to reset the score (keeps the time).';

  @override
  String get helpSettings =>
      'Swipe from the left edge to open Settings — dark theme, sounds, and this guide live there.';

  @override
  String get dontShowAgain => 'Don\'t show this again';

  @override
  String get continueLabel => 'Continue';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get darkTheme => 'Dark theme';

  @override
  String get yehorsSpecial => 'Yehor\'s special';

  @override
  String get yehorsSpecialSubtitle => 'Play a sound on Double hit';

  @override
  String get showTutorial => 'Show tutorial';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get selectTime => 'Select Time';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String minutesLabel(int count) {
    return '$count m';
  }

  @override
  String secondsLabel(int count) {
    return '$count s';
  }

  @override
  String get secondsShort => 's';

  @override
  String get dragUpForLogs => 'Drag up for logs';

  @override
  String get noEventsYet => 'No events yet';

  @override
  String get logFightStarted => 'Fight started';

  @override
  String logWarningTo(String name) {
    return 'Warning to $name';
  }

  @override
  String logCautionTo(String name) {
    return 'Caution to $name';
  }

  @override
  String get logDoubleHit => 'Double hit';

  @override
  String get standaloneMode => 'Standalone Timer';

  @override
  String get tournamentMode => 'Opossum Tournament';

  @override
  String get standaloneDescription =>
      'Works offline without an account or server. Bouts and logs stay in memory; restarting opens a new bout.';

  @override
  String get tournamentDescription =>
      'Connect to Opossum to load available bouts and submit confirmed results.';

  @override
  String get interruptedClock =>
      'Timing was interrupted. The clock is paused. Review the remaining time before starting again.';

  @override
  String get sessionNotRestored =>
      'New local bout. Previous scores and timing are not restored after restarting.';

  @override
  String get swapSides => 'Swap fighter sides';

  @override
  String get logPaused => 'Timer paused';

  @override
  String get logResumed => 'Timer resumed';

  @override
  String get logElapsed => 'Time expired';

  @override
  String get logInterrupted => 'Timing interrupted — review required';

  @override
  String get logTimeAdjusted => 'Remaining time adjusted';

  @override
  String get logSidesSwapped => 'Display sides swapped';

  @override
  String get logReset => 'New bout — scores and penalties cleared';

  @override
  String get leaveBoutTitle => 'Leave this bout?';

  @override
  String get leaveBoutMessage =>
      'This local bout and its log will be discarded. Nothing is sent to Opossum.';

  @override
  String get leaveBout => 'Leave bout';

  @override
  String get serverUrl => 'Opossum server URL';

  @override
  String get deviceToken => 'Device bearer token';

  @override
  String get testConnection => 'Test and save connection';

  @override
  String get connectionReady => 'Connection verified';

  @override
  String get chooseTournament => 'Select tournament';

  @override
  String get chooseNomination => 'Select nomination';

  @override
  String get worklist => 'Work assignments';

  @override
  String get refresh => 'Refresh';

  @override
  String get noWork =>
      'No Round-Robin work is available. Ask the organizer to generate and start the group.';

  @override
  String get noTournaments =>
      'No active nominations are available to this credential.';

  @override
  String get localHttp => 'Allow HTTP on localhost only (local development)';

  @override
  String get invalidConnection =>
      'Enter an HTTPS server origin and a device token. HTTP requires the explicit localhost development option.';

  @override
  String get secureStorageError =>
      'Secure credential storage is unavailable. Unlock/configure the system keychain and retry. Tokens are never saved as plaintext.';

  @override
  String get browserTokenNotice =>
      'This browser keeps the token only in memory. Enter it again after leaving or restarting.';

  @override
  String get onlineOnlyNotice =>
      'Online submission only. Pending requests are kept in memory, not on disk. Keep this screen open until acceptance is confirmed; restart can lose a pending request.';

  @override
  String get apiAuthentication =>
      'The device token is invalid, expired or revoked.';

  @override
  String get apiForbidden =>
      'This credential does not have permission for this operation or assignment.';

  @override
  String get apiConflict =>
      'Opossum has a different version or pairing. Your result was not applied. Ask the organizer to review it; automatic overwrite is disabled.';

  @override
  String get apiRejected =>
      'Opossum rejected this result. Ask the organizer to review the bout.';

  @override
  String get apiUnavailable =>
      'The server is unavailable. Check the address and connection.';

  @override
  String get apiTimeout =>
      'No confirmation arrived before the timeout. The request may have been accepted. Retry with the same request identifiers.';

  @override
  String get apiProtocol =>
      'Unexpected API response. The submission may be uncertain; do not enter a second result at the desk without checking.';

  @override
  String get apiCancelled => 'The request was cancelled.';

  @override
  String get apiRateLimited =>
      'Too many requests. Wait before retrying the same submission.';

  @override
  String get reviewResult => 'Review result';

  @override
  String get confirmSubmit => 'Confirm and submit';

  @override
  String get retrySubmission => 'Retry same submission';

  @override
  String get resultAccepted => 'Accepted by Opossum';

  @override
  String get duplicateAccepted =>
      'Previously accepted — confirmed by idempotent replay';

  @override
  String get acceptedAfterRetry =>
      'Accepted after retry (server replay status unavailable)';

  @override
  String get resultPending => 'Not submitted';

  @override
  String get resultSending => 'Awaiting authoritative confirmation';

  @override
  String get normalResult => 'Normal result';

  @override
  String get drawResult => 'Draw (NORMAL)';

  @override
  String get returnWorklist => 'Return to worklist';

  @override
  String get refreshFailed =>
      'The result was accepted, but refreshing the current bout/worklist failed. Refresh again; do not resubmit.';

  @override
  String get unsupportedHits =>
      'This API cannot submit changes to mutual hits. Restore the loaded count or have the organizer record the reviewed result and hits together.';

  @override
  String get localDiscipline =>
      'Remarks and warnings on this device are local notes only; they are not sent to Opossum.';

  @override
  String get boutUnavailable =>
      'This bout is no longer writable or is not supported by this first Round-Robin integration. Refresh the worklist.';

  @override
  String get leaveConnectedBout =>
      'Discard this local bout draft? Unconfirmed changes have not been sent to Opossum.';

  @override
  String get currentServerResult => 'Current server result';

  @override
  String get configurationLabel => 'Configuration';

  @override
  String get forgetConnection => 'Forget saved connection';

  @override
  String get resultUncertain => 'Acceptance unknown — retry the same request.';

  @override
  String get resultUnconfirmed => 'No authoritative acceptance confirmed.';

  @override
  String get choosePiste => 'Select physical piste';

  @override
  String get serverRevision => 'Server revision';

  @override
  String get recommendationHint =>
      'Recommended is a suggested order. Every ready bout remains selectable.';

  @override
  String get recommendedNext => 'Recommended next';

  @override
  String get readyBout => 'Ready for judging';

  @override
  String get activeWork => 'Active';

  @override
  String get plannedWork => 'Planned — not yet available';

  @override
  String get completedWork => 'Completed';

  @override
  String get awaitingSchedule => 'Awaiting schedule';

  @override
  String get waitingStage => 'Waiting for the organizer to start the stage';

  @override
  String get waitingGroup => 'Waiting for the organizer to start the group';

  @override
  String get waitingConfiguration =>
      'Waiting for Opossum to activate this configuration';

  @override
  String get waitingOtherPistes =>
      'Waiting for remaining bouts on other pistes';

  @override
  String get unavailableWork => 'Unavailable — refresh or ask the organizer';

  @override
  String get cancelledWork => 'Cancelled';

  @override
  String get voidWork => 'Annulled';

  @override
  String get stageLocked => 'Stage locked for scoring';

  @override
  String get fightersHere => 'Fighters on this piste';

  @override
  String get previousConfiguration => 'Previous configuration';

  @override
  String get nextConfiguration => 'Next configuration';

  @override
  String get previousPopulation => 'Previously assigned';

  @override
  String get currentPopulation => 'Assigned in this configuration';

  @override
  String get nextPopulation => 'Next assigned fighters';

  @override
  String get transitionAuthority =>
      'The organizer starts groups; Opossum activates the next configuration after all its current bouts resolve.';

  @override
  String get remainingHere => 'Remaining here';

  @override
  String get remainingElsewhere =>
      'Remaining on other pistes in this configuration';

  @override
  String get executionStep => 'Step';

  @override
  String get otherReadyBout => 'Choose another ready bout?';

  @override
  String get otherReadyExplanation =>
      'This is not the recommended next bout, but Opossum permits judging it. Confirm the pairing with the organizer.';

  @override
  String get upcomingWork => 'Current and upcoming work';

  @override
  String get activeBoutRetained =>
      'Refreshing never replaces this local bout or its fighters. Finish or explicitly leave it before changing piste.';

  @override
  String get activeBoutChanged =>
      'Opossum changed this bout or its availability. Your local draft is preserved. Do not submit it as a new result; ask the organizer to review.';

  @override
  String get fightersChanged =>
      'Fighters change pistes — check the current assignment before judging';

  @override
  String get fightersLeaving => 'Leaving this piste';

  @override
  String get fightersArriving => 'Arriving on this piste';

  @override
  String get waitingGroupCompletion =>
      'Bouts resolved — awaiting organizer group completion';

  @override
  String get waitingTieBreak => 'Awaiting tie-break resolution';

  @override
  String get waitingJudgeSheet => 'Awaiting judge-sheet closure';

  @override
  String get savedOnDevice =>
      'Saved on this device — awaiting Opossum confirmation.';

  @override
  String get draftSavedOnDevice => 'Draft saved on this device';

  @override
  String get savingLocally => 'Saving on this device…';

  @override
  String get durableModeNotice =>
      'Scores and confirmed results are stored on this device. Only an Opossum acknowledgement makes a result official.';

  @override
  String get durableStorageError =>
      'Local storage failed or is unavailable. Keep this screen open and retry. Do not treat unsaved changes as durable.';

  @override
  String get pendingResults => 'Results awaiting synchronization';

  @override
  String get pendingLeaveWarning =>
      'Unsynchronized confirmed results remain on this device. Leaving or changing assignment does not delete them. Return with the same server and original device credential to synchronize. Pending count:';

  @override
  String get openSavedOffline => 'Open saved tournament offline';

  @override
  String get offlineMode => 'Offline / cached work';

  @override
  String get cachedWorkWarning =>
      'This is a cached server snapshot. Availability may have changed. Only previously READY bouts can be selected; future configurations never advance locally. Opossum will validate every confirmed result on reconnect.';

  @override
  String get resumeSavedBout => 'Resume saved bout draft';

  @override
  String get recoveredClockNotice =>
      'Recovered paused at the last saved clock reading. Time since interruption is unknown. Review and deliberately adjust the clock before resuming; scores and fighter IDs are preserved.';

  @override
  String get leaveSavedBout =>
      'Leave this bout? Its saved draft remains on this device. Unconfirmed scores have not been sent as an official result.';

  @override
  String get outboxExplanation =>
      'Local results are retained with their original request identity. Conflicts require review at the organizer desk; this device never overwrites a competing result.';

  @override
  String get reconnectForSync =>
      'Reconnect with the original device credential to synchronize. A replaced credential cannot safely replay an uncertain request.';

  @override
  String get handledAtDesk => 'Handled at organizer desk';

  @override
  String get handledExplanation =>
      'Confirm only after the organizer has reviewed this result. This records a local resolution and keeps all evidence; it does not change Opossum scores or approve a correction.';

  @override
  String get reviewReason => 'Review reason';

  @override
  String get confirmReview => 'Confirm reviewed resolution';

  @override
  String get syncReason => 'Synchronization reason';

  @override
  String get dependencyNotice =>
      'This entry waits for acknowledgement of its required earlier operations.';

  @override
  String get browserPersistenceNotice =>
      'Browser storage is not protected from automatic eviction. Do not clear site data or use private browsing while results are pending. Keep the original device token for recovery.';

  @override
  String get retryPausedNotice =>
      'Automatic retries paused after repeated failures. The result is retained. Check the connection, then retry explicitly.';

  @override
  String get judgingTitle => 'Official judging';

  @override
  String get judgeRemark => 'Remark';

  @override
  String get judgeWarning => 'Warning';

  @override
  String get judgeMutualHit => 'Mutual hits';

  @override
  String get judgingPending => 'Pending actions (not official)';

  @override
  String get judgingConfirm => 'Confirm actual judging event';

  @override
  String get judgingConfirmExplanation =>
      'Confirm only an event that actually occurred. Opossum determines its sporting consequences.';

  @override
  String judgingPolicy(int remarks, int warnings) {
    return 'Active policy: $remarks remarks per warning; $warnings warnings for disqualification.';
  }

  @override
  String judgingHitPolicy(int threshold, String action) {
    return 'Mutual hits: threshold $threshold · $action';
  }

  @override
  String judgingRefight(int attempt) {
    return 'Refight · attempt $attempt';
  }

  @override
  String get judgingSuddenDeath => 'Sudden death — first clean decisive hit';

  @override
  String get judgingStandard => 'Ordinary bout';

  @override
  String get judgingDoubleLoss => 'Double Loss — confirmed by Opossum';

  @override
  String get judgingDisqualified => 'Disqualified — confirmed by Opossum';

  @override
  String get judgingReview =>
      'Accepted judging records can only be corrected at the organizer desk. Do not decrement official counts.';

  @override
  String get judgingHistory => 'Official judging history';

  @override
  String get judgingUnavailable =>
      'Official judging is unavailable. Local penalties are disabled in tournament mode.';

  @override
  String get judgingNoScope =>
      'This credential cannot issue judging events. Ask the organizer for judge-write access.';

  @override
  String get judgingOffline =>
      'Offline actions remain local evidence. The official count and continuation are unknown until Opossum confirms them.';

  @override
  String get judgingWaitResult =>
      'Synchronize or resolve judging actions before confirming a result. Scores remain saved on this device.';

  @override
  String get judgingCancelLocal => 'Cancel unsent action';

  @override
  String get judgingCancelledLocal =>
      'Cancelled before submission (not official)';

  @override
  String get judgingAccepted => 'Official state from Opossum';

  @override
  String get judgingRecordVoided => 'Voided by organizer';

  @override
  String judgingScoreSnapshot(int scoreA, int scoreB) {
    return 'Current scores to attest: $scoreA:$scoreB';
  }

  @override
  String get judgingDisabledPolicy => 'Disabled by stage policy';

  @override
  String get judgingDoubleLossPolicy => 'Double Loss';

  @override
  String get judgingRefightPolicy => 'Refights';

  @override
  String get judgingHybridPolicy => 'Refights, then sudden death';

  @override
  String get judgingSyncBlocked =>
      'Judging actions require organizer review; local evidence is retained.';

  @override
  String get judgingContinuationTitle => 'Review confirmed continuation';

  @override
  String get judgingContinuationReview =>
      'Opossum confirmed a new attempt. The clock is paused and your previous local scores are retained. Review them before clearing the draft for the new attempt.';

  @override
  String get judgingStartAttempt => 'Start confirmed attempt';

  @override
  String get judgingResultReview =>
      'Judging actions synchronize separately. This score is official only after Opossum accepts the result.';

  @override
  String get judgingScoresRequired =>
      'Both current scores are required for this hit. Atomic score submission also needs result-write permission; otherwise ask the organizer.';

  @override
  String get operationalBouts => 'Elimination & tie-break bouts';

  @override
  String get operationalSelection => 'Select an unreserved bout?';

  @override
  String get operationalWarning =>
      'Selection is local to this device, not an exclusive reservation. Confirm with the organizer before fencing: another timer may select the same bout. A newer result or changed pairing requires desk review; your local evidence is retained.';

  @override
  String get unassignedPiste => 'No assigned piste';

  @override
  String get automaticWin => 'Automatic win — no fight or numeric submission';

  @override
  String get bronzeFirst => 'Complete the bronze bout before the gold final';

  @override
  String get stageTieBreak => 'Stage tie-break';

  @override
  String get groupTieBreak => 'Group tie-break';

  @override
  String get semifinalBout => 'Semifinal';

  @override
  String get bronzeBout => 'Bronze match';

  @override
  String get goldBout => 'Gold/Silver final';

  @override
  String get eliminationRound => 'Elimination round';

  @override
  String get scanPairingQr => 'Scan pairing QR';

  @override
  String get pairingLink => 'One-time pairing link';

  @override
  String get usePairingLink => 'Use pairing link';

  @override
  String get manualConnection => 'Manual URL + device token';

  @override
  String get pairingIntro =>
      'Ask the organizer for a one-time QR. Review the server address before connecting.';

  @override
  String get cameraUnavailable =>
      'Camera scanning is unavailable or permission was denied. Use the pairing link or manual connection below.';

  @override
  String get invalidPairingQr =>
      'Invalid pairing QR. Ask for a current Opossum one-time pairing code and an HTTPS server.';

  @override
  String get pairingConfirm => 'Connect to this Opossum server?';

  @override
  String get repairEvidenceNotice =>
      'Re-pairing does not delete saved scores or confirmed operations. Requests tied to the old credential will not be reassigned to a new token: review them with the organizer. An expired, used or uncertain pairing needs a new QR.';
}
