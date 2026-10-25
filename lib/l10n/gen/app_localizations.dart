import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uk'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Scoreboard'**
  String get appTitle;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @caution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get caution;

  /// No description provided for @double.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get double;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get helpTitle;

  /// No description provided for @helpTap.
  ///
  /// In en, this message translates to:
  /// **'Tap a number to add a point.'**
  String get helpTap;

  /// No description provided for @helpLongPress.
  ///
  /// In en, this message translates to:
  /// **'Long-press a number to remove a point.'**
  String get helpLongPress;

  /// No description provided for @helpTimer.
  ///
  /// In en, this message translates to:
  /// **'Long-press the timer to change the round time.'**
  String get helpTimer;

  /// No description provided for @helpLog.
  ///
  /// In en, this message translates to:
  /// **'Drag the log bar up to open the fight log.'**
  String get helpLog;

  /// No description provided for @helpResetScore.
  ///
  /// In en, this message translates to:
  /// **'Long-press Reset to reset the score (keeps the time).'**
  String get helpResetScore;

  /// No description provided for @helpSettings.
  ///
  /// In en, this message translates to:
  /// **'Swipe from the left edge to open Settings — dark theme, sounds, and this guide live there.'**
  String get helpSettings;

  /// No description provided for @dontShowAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this again'**
  String get dontShowAgain;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get darkTheme;

  /// No description provided for @yehorsSpecial.
  ///
  /// In en, this message translates to:
  /// **'Yehor\'s special'**
  String get yehorsSpecial;

  /// No description provided for @yehorsSpecialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play a sound on Double hit'**
  String get yehorsSpecialSubtitle;

  /// No description provided for @showTutorial.
  ///
  /// In en, this message translates to:
  /// **'Show tutorial'**
  String get showTutorial;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @minutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} m'**
  String minutesLabel(int count);

  /// No description provided for @secondsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} s'**
  String secondsLabel(int count);

  /// Abbreviation for seconds used on the time-adjust buttons, e.g. the 's' in '+3s'.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get secondsShort;

  /// No description provided for @dragUpForLogs.
  ///
  /// In en, this message translates to:
  /// **'Drag up for logs'**
  String get dragUpForLogs;

  /// No description provided for @noEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get noEventsYet;

  /// No description provided for @logFightStarted.
  ///
  /// In en, this message translates to:
  /// **'Fight started'**
  String get logFightStarted;

  /// No description provided for @logWarningTo.
  ///
  /// In en, this message translates to:
  /// **'Warning to {name}'**
  String logWarningTo(String name);

  /// No description provided for @logCautionTo.
  ///
  /// In en, this message translates to:
  /// **'Caution to {name}'**
  String logCautionTo(String name);

  /// No description provided for @logDoubleHit.
  ///
  /// In en, this message translates to:
  /// **'Double hit'**
  String get logDoubleHit;

  /// No description provided for @standaloneMode.
  ///
  /// In en, this message translates to:
  /// **'Standalone Timer'**
  String get standaloneMode;

  /// No description provided for @tournamentMode.
  ///
  /// In en, this message translates to:
  /// **'Opossum Tournament'**
  String get tournamentMode;

  /// No description provided for @standaloneDescription.
  ///
  /// In en, this message translates to:
  /// **'Works offline without an account or server. Bouts and logs stay in memory; restarting opens a new bout.'**
  String get standaloneDescription;

  /// No description provided for @tournamentDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to Opossum to load available bouts and submit confirmed results.'**
  String get tournamentDescription;

  /// No description provided for @interruptedClock.
  ///
  /// In en, this message translates to:
  /// **'Timing was interrupted. The clock is paused. Review the remaining time before starting again.'**
  String get interruptedClock;

  /// No description provided for @sessionNotRestored.
  ///
  /// In en, this message translates to:
  /// **'New local bout. Previous scores and timing are not restored after restarting.'**
  String get sessionNotRestored;

  /// No description provided for @swapSides.
  ///
  /// In en, this message translates to:
  /// **'Swap fighter sides'**
  String get swapSides;

  /// No description provided for @logPaused.
  ///
  /// In en, this message translates to:
  /// **'Timer paused'**
  String get logPaused;

  /// No description provided for @logResumed.
  ///
  /// In en, this message translates to:
  /// **'Timer resumed'**
  String get logResumed;

  /// No description provided for @logElapsed.
  ///
  /// In en, this message translates to:
  /// **'Time expired'**
  String get logElapsed;

  /// No description provided for @logInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Timing interrupted — review required'**
  String get logInterrupted;

  /// No description provided for @logTimeAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Remaining time adjusted'**
  String get logTimeAdjusted;

  /// No description provided for @logSidesSwapped.
  ///
  /// In en, this message translates to:
  /// **'Display sides swapped'**
  String get logSidesSwapped;

  /// No description provided for @logReset.
  ///
  /// In en, this message translates to:
  /// **'New bout — scores and penalties cleared'**
  String get logReset;

  /// No description provided for @leaveBoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this bout?'**
  String get leaveBoutTitle;

  /// No description provided for @leaveBoutMessage.
  ///
  /// In en, this message translates to:
  /// **'This local bout and its log will be discarded. Nothing is sent to Opossum.'**
  String get leaveBoutMessage;

  /// No description provided for @leaveBout.
  ///
  /// In en, this message translates to:
  /// **'Leave bout'**
  String get leaveBout;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Opossum server URL'**
  String get serverUrl;

  /// No description provided for @deviceToken.
  ///
  /// In en, this message translates to:
  /// **'Device bearer token'**
  String get deviceToken;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test and save connection'**
  String get testConnection;

  /// No description provided for @connectionReady.
  ///
  /// In en, this message translates to:
  /// **'Connection verified'**
  String get connectionReady;

  /// No description provided for @chooseTournament.
  ///
  /// In en, this message translates to:
  /// **'Select tournament'**
  String get chooseTournament;

  /// No description provided for @chooseNomination.
  ///
  /// In en, this message translates to:
  /// **'Select nomination'**
  String get chooseNomination;

  /// No description provided for @worklist.
  ///
  /// In en, this message translates to:
  /// **'Work assignments'**
  String get worklist;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noWork.
  ///
  /// In en, this message translates to:
  /// **'No Round-Robin work is available. Ask the organizer to generate and start the group.'**
  String get noWork;

  /// No description provided for @noTournaments.
  ///
  /// In en, this message translates to:
  /// **'No active nominations are available to this credential.'**
  String get noTournaments;

  /// No description provided for @localHttp.
  ///
  /// In en, this message translates to:
  /// **'Allow HTTP on localhost only (local development)'**
  String get localHttp;

  /// No description provided for @invalidConnection.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTPS server origin and a device token. HTTP requires the explicit localhost development option.'**
  String get invalidConnection;

  /// No description provided for @secureStorageError.
  ///
  /// In en, this message translates to:
  /// **'Secure credential storage is unavailable. Unlock/configure the system keychain and retry. Tokens are never saved as plaintext.'**
  String get secureStorageError;

  /// No description provided for @browserTokenNotice.
  ///
  /// In en, this message translates to:
  /// **'This browser keeps the token only in memory. Enter it again after leaving or restarting.'**
  String get browserTokenNotice;

  /// No description provided for @onlineOnlyNotice.
  ///
  /// In en, this message translates to:
  /// **'Online submission only. Pending requests are kept in memory, not on disk. Keep this screen open until acceptance is confirmed; restart can lose a pending request.'**
  String get onlineOnlyNotice;

  /// No description provided for @apiAuthentication.
  ///
  /// In en, this message translates to:
  /// **'The device token is invalid, expired or revoked.'**
  String get apiAuthentication;

  /// No description provided for @apiForbidden.
  ///
  /// In en, this message translates to:
  /// **'This credential does not have permission for this operation or assignment.'**
  String get apiForbidden;

  /// No description provided for @apiConflict.
  ///
  /// In en, this message translates to:
  /// **'Opossum has a different version or pairing. Your result was not applied. Ask the organizer to review it; automatic overwrite is disabled.'**
  String get apiConflict;

  /// No description provided for @apiRejected.
  ///
  /// In en, this message translates to:
  /// **'Opossum rejected this result. Ask the organizer to review the bout.'**
  String get apiRejected;

  /// No description provided for @apiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The server is unavailable. Check the address and connection.'**
  String get apiUnavailable;

  /// No description provided for @apiTimeout.
  ///
  /// In en, this message translates to:
  /// **'No confirmation arrived before the timeout. The request may have been accepted. Retry with the same request identifiers.'**
  String get apiTimeout;

  /// No description provided for @apiProtocol.
  ///
  /// In en, this message translates to:
  /// **'Unexpected API response. The submission may be uncertain; do not enter a second result at the desk without checking.'**
  String get apiProtocol;

  /// No description provided for @apiCancelled.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get apiCancelled;

  /// No description provided for @apiRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Wait before retrying the same submission.'**
  String get apiRateLimited;

  /// No description provided for @reviewResult.
  ///
  /// In en, this message translates to:
  /// **'Review result'**
  String get reviewResult;

  /// No description provided for @confirmSubmit.
  ///
  /// In en, this message translates to:
  /// **'Confirm and submit'**
  String get confirmSubmit;

  /// No description provided for @retrySubmission.
  ///
  /// In en, this message translates to:
  /// **'Retry same submission'**
  String get retrySubmission;

  /// No description provided for @resultAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted by Opossum'**
  String get resultAccepted;

  /// No description provided for @duplicateAccepted.
  ///
  /// In en, this message translates to:
  /// **'Previously accepted — confirmed by idempotent replay'**
  String get duplicateAccepted;

  /// No description provided for @acceptedAfterRetry.
  ///
  /// In en, this message translates to:
  /// **'Accepted after retry (server replay status unavailable)'**
  String get acceptedAfterRetry;

  /// No description provided for @resultPending.
  ///
  /// In en, this message translates to:
  /// **'Not submitted'**
  String get resultPending;

  /// No description provided for @resultSending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting authoritative confirmation'**
  String get resultSending;

  /// No description provided for @normalResult.
  ///
  /// In en, this message translates to:
  /// **'Normal result'**
  String get normalResult;

  /// No description provided for @drawResult.
  ///
  /// In en, this message translates to:
  /// **'Draw (NORMAL)'**
  String get drawResult;

  /// No description provided for @returnWorklist.
  ///
  /// In en, this message translates to:
  /// **'Return to worklist'**
  String get returnWorklist;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'The result was accepted, but refreshing the current bout/worklist failed. Refresh again; do not resubmit.'**
  String get refreshFailed;

  /// No description provided for @unsupportedHits.
  ///
  /// In en, this message translates to:
  /// **'This API cannot submit changes to mutual hits. Restore the loaded count or have the organizer record the reviewed result and hits together.'**
  String get unsupportedHits;

  /// No description provided for @localDiscipline.
  ///
  /// In en, this message translates to:
  /// **'Remarks and warnings on this device are local notes only; they are not sent to Opossum.'**
  String get localDiscipline;

  /// No description provided for @boutUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This bout is no longer writable or is not supported by this first Round-Robin integration. Refresh the worklist.'**
  String get boutUnavailable;

  /// No description provided for @leaveConnectedBout.
  ///
  /// In en, this message translates to:
  /// **'Discard this local bout draft? Unconfirmed changes have not been sent to Opossum.'**
  String get leaveConnectedBout;

  /// No description provided for @currentServerResult.
  ///
  /// In en, this message translates to:
  /// **'Current server result'**
  String get currentServerResult;

  /// No description provided for @configurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configurationLabel;

  /// No description provided for @forgetConnection.
  ///
  /// In en, this message translates to:
  /// **'Forget saved connection'**
  String get forgetConnection;

  /// No description provided for @resultUncertain.
  ///
  /// In en, this message translates to:
  /// **'Acceptance unknown — retry the same request.'**
  String get resultUncertain;

  /// No description provided for @resultUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'No authoritative acceptance confirmed.'**
  String get resultUnconfirmed;

  /// No description provided for @choosePiste.
  ///
  /// In en, this message translates to:
  /// **'Select physical piste'**
  String get choosePiste;

  /// No description provided for @serverRevision.
  ///
  /// In en, this message translates to:
  /// **'Server revision'**
  String get serverRevision;

  /// No description provided for @recommendationHint.
  ///
  /// In en, this message translates to:
  /// **'Recommended is a suggested order. Every ready bout remains selectable.'**
  String get recommendationHint;

  /// No description provided for @recommendedNext.
  ///
  /// In en, this message translates to:
  /// **'Recommended next'**
  String get recommendedNext;

  /// No description provided for @readyBout.
  ///
  /// In en, this message translates to:
  /// **'Ready for judging'**
  String get readyBout;

  /// No description provided for @activeWork.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeWork;

  /// No description provided for @plannedWork.
  ///
  /// In en, this message translates to:
  /// **'Planned — not yet available'**
  String get plannedWork;

  /// No description provided for @completedWork.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedWork;

  /// No description provided for @awaitingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Awaiting schedule'**
  String get awaitingSchedule;

  /// No description provided for @waitingStage.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the organizer to start the stage'**
  String get waitingStage;

  /// No description provided for @waitingGroup.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the organizer to start the group'**
  String get waitingGroup;

  /// No description provided for @waitingConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Opossum to activate this configuration'**
  String get waitingConfiguration;

  /// No description provided for @waitingOtherPistes.
  ///
  /// In en, this message translates to:
  /// **'Waiting for remaining bouts on other pistes'**
  String get waitingOtherPistes;

  /// No description provided for @unavailableWork.
  ///
  /// In en, this message translates to:
  /// **'Unavailable — refresh or ask the organizer'**
  String get unavailableWork;

  /// No description provided for @cancelledWork.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledWork;

  /// No description provided for @voidWork.
  ///
  /// In en, this message translates to:
  /// **'Annulled'**
  String get voidWork;

  /// No description provided for @stageLocked.
  ///
  /// In en, this message translates to:
  /// **'Stage locked for scoring'**
  String get stageLocked;

  /// No description provided for @fightersHere.
  ///
  /// In en, this message translates to:
  /// **'Fighters on this piste'**
  String get fightersHere;

  /// No description provided for @previousConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Previous configuration'**
  String get previousConfiguration;

  /// No description provided for @nextConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Next configuration'**
  String get nextConfiguration;

  /// No description provided for @previousPopulation.
  ///
  /// In en, this message translates to:
  /// **'Previously assigned'**
  String get previousPopulation;

  /// No description provided for @currentPopulation.
  ///
  /// In en, this message translates to:
  /// **'Assigned in this configuration'**
  String get currentPopulation;

  /// No description provided for @nextPopulation.
  ///
  /// In en, this message translates to:
  /// **'Next assigned fighters'**
  String get nextPopulation;

  /// No description provided for @transitionAuthority.
  ///
  /// In en, this message translates to:
  /// **'The organizer starts groups; Opossum activates the next configuration after all its current bouts resolve.'**
  String get transitionAuthority;

  /// No description provided for @remainingHere.
  ///
  /// In en, this message translates to:
  /// **'Remaining here'**
  String get remainingHere;

  /// No description provided for @remainingElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Remaining on other pistes in this configuration'**
  String get remainingElsewhere;

  /// No description provided for @executionStep.
  ///
  /// In en, this message translates to:
  /// **'Step'**
  String get executionStep;

  /// No description provided for @otherReadyBout.
  ///
  /// In en, this message translates to:
  /// **'Choose another ready bout?'**
  String get otherReadyBout;

  /// No description provided for @otherReadyExplanation.
  ///
  /// In en, this message translates to:
  /// **'This is not the recommended next bout, but Opossum permits judging it. Confirm the pairing with the organizer.'**
  String get otherReadyExplanation;

  /// No description provided for @upcomingWork.
  ///
  /// In en, this message translates to:
  /// **'Current and upcoming work'**
  String get upcomingWork;

  /// No description provided for @activeBoutRetained.
  ///
  /// In en, this message translates to:
  /// **'Refreshing never replaces this local bout or its fighters. Finish or explicitly leave it before changing piste.'**
  String get activeBoutRetained;

  /// No description provided for @activeBoutChanged.
  ///
  /// In en, this message translates to:
  /// **'Opossum changed this bout or its availability. Your local draft is preserved. Do not submit it as a new result; ask the organizer to review.'**
  String get activeBoutChanged;

  /// No description provided for @fightersChanged.
  ///
  /// In en, this message translates to:
  /// **'Fighters change pistes — check the current assignment before judging'**
  String get fightersChanged;

  /// No description provided for @fightersLeaving.
  ///
  /// In en, this message translates to:
  /// **'Leaving this piste'**
  String get fightersLeaving;

  /// No description provided for @fightersArriving.
  ///
  /// In en, this message translates to:
  /// **'Arriving on this piste'**
  String get fightersArriving;

  /// No description provided for @waitingGroupCompletion.
  ///
  /// In en, this message translates to:
  /// **'Bouts resolved — awaiting organizer group completion'**
  String get waitingGroupCompletion;

  /// No description provided for @waitingTieBreak.
  ///
  /// In en, this message translates to:
  /// **'Awaiting tie-break resolution'**
  String get waitingTieBreak;

  /// No description provided for @waitingJudgeSheet.
  ///
  /// In en, this message translates to:
  /// **'Awaiting judge-sheet closure'**
  String get waitingJudgeSheet;

  /// No description provided for @savedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device — awaiting Opossum confirmation.'**
  String get savedOnDevice;

  /// No description provided for @draftSavedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Draft saved on this device'**
  String get draftSavedOnDevice;

  /// No description provided for @savingLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving on this device…'**
  String get savingLocally;

  /// No description provided for @durableModeNotice.
  ///
  /// In en, this message translates to:
  /// **'Scores and confirmed results are stored on this device. Only an Opossum acknowledgement makes a result official.'**
  String get durableModeNotice;

  /// No description provided for @durableStorageError.
  ///
  /// In en, this message translates to:
  /// **'Local storage failed or is unavailable. Keep this screen open and retry. Do not treat unsaved changes as durable.'**
  String get durableStorageError;

  /// No description provided for @pendingResults.
  ///
  /// In en, this message translates to:
  /// **'Results awaiting synchronization'**
  String get pendingResults;

  /// No description provided for @pendingLeaveWarning.
  ///
  /// In en, this message translates to:
  /// **'Unsynchronized confirmed results remain on this device. Leaving or changing assignment does not delete them. Return with the same server and original device credential to synchronize. Pending count:'**
  String get pendingLeaveWarning;

  /// No description provided for @openSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Open saved tournament offline'**
  String get openSavedOffline;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline / cached work'**
  String get offlineMode;

  /// No description provided for @cachedWorkWarning.
  ///
  /// In en, this message translates to:
  /// **'This is a cached server snapshot. Availability may have changed. Only previously READY bouts can be selected; future configurations never advance locally. Opossum will validate every confirmed result on reconnect.'**
  String get cachedWorkWarning;

  /// No description provided for @resumeSavedBout.
  ///
  /// In en, this message translates to:
  /// **'Resume saved bout draft'**
  String get resumeSavedBout;

  /// No description provided for @recoveredClockNotice.
  ///
  /// In en, this message translates to:
  /// **'Recovered paused at the last saved clock reading. Time since interruption is unknown. Review and deliberately adjust the clock before resuming; scores and fighter IDs are preserved.'**
  String get recoveredClockNotice;

  /// No description provided for @leaveSavedBout.
  ///
  /// In en, this message translates to:
  /// **'Leave this bout? Its saved draft remains on this device. Unconfirmed scores have not been sent as an official result.'**
  String get leaveSavedBout;

  /// No description provided for @outboxExplanation.
  ///
  /// In en, this message translates to:
  /// **'Local results are retained with their original request identity. Conflicts require review at the organizer desk; this device never overwrites a competing result.'**
  String get outboxExplanation;

  /// No description provided for @reconnectForSync.
  ///
  /// In en, this message translates to:
  /// **'Reconnect with the original device credential to synchronize. A replaced credential cannot safely replay an uncertain request.'**
  String get reconnectForSync;

  /// No description provided for @handledAtDesk.
  ///
  /// In en, this message translates to:
  /// **'Handled at organizer desk'**
  String get handledAtDesk;

  /// No description provided for @handledExplanation.
  ///
  /// In en, this message translates to:
  /// **'Confirm only after the organizer has reviewed this result. This records a local resolution and keeps all evidence; it does not change Opossum scores or approve a correction.'**
  String get handledExplanation;

  /// No description provided for @reviewReason.
  ///
  /// In en, this message translates to:
  /// **'Review reason'**
  String get reviewReason;

  /// No description provided for @confirmReview.
  ///
  /// In en, this message translates to:
  /// **'Confirm reviewed resolution'**
  String get confirmReview;

  /// No description provided for @syncReason.
  ///
  /// In en, this message translates to:
  /// **'Synchronization reason'**
  String get syncReason;

  /// No description provided for @dependencyNotice.
  ///
  /// In en, this message translates to:
  /// **'This entry waits for acknowledgement of its required earlier operations.'**
  String get dependencyNotice;

  /// No description provided for @browserPersistenceNotice.
  ///
  /// In en, this message translates to:
  /// **'Browser storage is not protected from automatic eviction. Do not clear site data or use private browsing while results are pending. Keep the original device token for recovery.'**
  String get browserPersistenceNotice;

  /// No description provided for @retryPausedNotice.
  ///
  /// In en, this message translates to:
  /// **'Automatic retries paused after repeated failures. The result is retained. Check the connection, then retry explicitly.'**
  String get retryPausedNotice;

  /// No description provided for @judgingTitle.
  ///
  /// In en, this message translates to:
  /// **'Official judging'**
  String get judgingTitle;

  /// No description provided for @judgeRemark.
  ///
  /// In en, this message translates to:
  /// **'Remark'**
  String get judgeRemark;

  /// No description provided for @judgeWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get judgeWarning;

  /// No description provided for @judgeMutualHit.
  ///
  /// In en, this message translates to:
  /// **'Mutual hits'**
  String get judgeMutualHit;

  /// No description provided for @judgingPending.
  ///
  /// In en, this message translates to:
  /// **'Pending actions (not official)'**
  String get judgingPending;

  /// No description provided for @judgingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm actual judging event'**
  String get judgingConfirm;

  /// No description provided for @judgingConfirmExplanation.
  ///
  /// In en, this message translates to:
  /// **'Confirm only an event that actually occurred. Opossum determines its sporting consequences.'**
  String get judgingConfirmExplanation;

  /// No description provided for @judgingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Active policy: {remarks} remarks per warning; {warnings} warnings for disqualification.'**
  String judgingPolicy(int remarks, int warnings);

  /// No description provided for @judgingHitPolicy.
  ///
  /// In en, this message translates to:
  /// **'Mutual hits: threshold {threshold} · {action}'**
  String judgingHitPolicy(int threshold, String action);

  /// No description provided for @judgingRefight.
  ///
  /// In en, this message translates to:
  /// **'Refight · attempt {attempt}'**
  String judgingRefight(int attempt);

  /// No description provided for @judgingSuddenDeath.
  ///
  /// In en, this message translates to:
  /// **'Sudden death — first clean decisive hit'**
  String get judgingSuddenDeath;

  /// No description provided for @judgingStandard.
  ///
  /// In en, this message translates to:
  /// **'Ordinary bout'**
  String get judgingStandard;

  /// No description provided for @judgingDoubleLoss.
  ///
  /// In en, this message translates to:
  /// **'Double Loss — confirmed by Opossum'**
  String get judgingDoubleLoss;

  /// No description provided for @judgingDisqualified.
  ///
  /// In en, this message translates to:
  /// **'Disqualified — confirmed by Opossum'**
  String get judgingDisqualified;

  /// No description provided for @judgingReview.
  ///
  /// In en, this message translates to:
  /// **'Accepted judging records can only be corrected at the organizer desk. Do not decrement official counts.'**
  String get judgingReview;

  /// No description provided for @judgingHistory.
  ///
  /// In en, this message translates to:
  /// **'Official judging history'**
  String get judgingHistory;

  /// No description provided for @judgingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Official judging is unavailable. Local penalties are disabled in tournament mode.'**
  String get judgingUnavailable;

  /// No description provided for @judgingNoScope.
  ///
  /// In en, this message translates to:
  /// **'This credential cannot issue judging events. Ask the organizer for judge-write access.'**
  String get judgingNoScope;

  /// No description provided for @judgingOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline actions remain local evidence. The official count and continuation are unknown until Opossum confirms them.'**
  String get judgingOffline;

  /// No description provided for @judgingWaitResult.
  ///
  /// In en, this message translates to:
  /// **'Synchronize or resolve judging actions before confirming a result. Scores remain saved on this device.'**
  String get judgingWaitResult;

  /// No description provided for @judgingCancelLocal.
  ///
  /// In en, this message translates to:
  /// **'Cancel unsent action'**
  String get judgingCancelLocal;

  /// No description provided for @judgingCancelledLocal.
  ///
  /// In en, this message translates to:
  /// **'Cancelled before submission (not official)'**
  String get judgingCancelledLocal;

  /// No description provided for @judgingAccepted.
  ///
  /// In en, this message translates to:
  /// **'Official state from Opossum'**
  String get judgingAccepted;

  /// No description provided for @judgingRecordVoided.
  ///
  /// In en, this message translates to:
  /// **'Voided by organizer'**
  String get judgingRecordVoided;

  /// No description provided for @judgingScoreSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Current scores to attest: {scoreA}:{scoreB}'**
  String judgingScoreSnapshot(int scoreA, int scoreB);

  /// No description provided for @judgingDisabledPolicy.
  ///
  /// In en, this message translates to:
  /// **'Disabled by stage policy'**
  String get judgingDisabledPolicy;

  /// No description provided for @judgingDoubleLossPolicy.
  ///
  /// In en, this message translates to:
  /// **'Double Loss'**
  String get judgingDoubleLossPolicy;

  /// No description provided for @judgingRefightPolicy.
  ///
  /// In en, this message translates to:
  /// **'Refights'**
  String get judgingRefightPolicy;

  /// No description provided for @judgingHybridPolicy.
  ///
  /// In en, this message translates to:
  /// **'Refights, then sudden death'**
  String get judgingHybridPolicy;

  /// No description provided for @judgingSyncBlocked.
  ///
  /// In en, this message translates to:
  /// **'Judging actions require organizer review; local evidence is retained.'**
  String get judgingSyncBlocked;

  /// No description provided for @judgingContinuationTitle.
  ///
  /// In en, this message translates to:
  /// **'Review confirmed continuation'**
  String get judgingContinuationTitle;

  /// No description provided for @judgingContinuationReview.
  ///
  /// In en, this message translates to:
  /// **'Opossum confirmed a new attempt. The clock is paused and your previous local scores are retained. Review them before clearing the draft for the new attempt.'**
  String get judgingContinuationReview;

  /// No description provided for @judgingStartAttempt.
  ///
  /// In en, this message translates to:
  /// **'Start confirmed attempt'**
  String get judgingStartAttempt;

  /// No description provided for @judgingResultReview.
  ///
  /// In en, this message translates to:
  /// **'Judging actions synchronize separately. This score is official only after Opossum accepts the result.'**
  String get judgingResultReview;

  /// No description provided for @judgingScoresRequired.
  ///
  /// In en, this message translates to:
  /// **'Both current scores are required for this hit. Atomic score submission also needs result-write permission; otherwise ask the organizer.'**
  String get judgingScoresRequired;

  /// No description provided for @operationalBouts.
  ///
  /// In en, this message translates to:
  /// **'Elimination & tie-break bouts'**
  String get operationalBouts;

  /// No description provided for @operationalSelection.
  ///
  /// In en, this message translates to:
  /// **'Select an unreserved bout?'**
  String get operationalSelection;

  /// No description provided for @operationalWarning.
  ///
  /// In en, this message translates to:
  /// **'Selection is local to this device, not an exclusive reservation. Confirm with the organizer before fencing: another timer may select the same bout. A newer result or changed pairing requires desk review; your local evidence is retained.'**
  String get operationalWarning;

  /// No description provided for @unassignedPiste.
  ///
  /// In en, this message translates to:
  /// **'No assigned piste'**
  String get unassignedPiste;

  /// No description provided for @automaticWin.
  ///
  /// In en, this message translates to:
  /// **'Automatic win — no fight or numeric submission'**
  String get automaticWin;

  /// No description provided for @bronzeFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete the bronze bout before the gold final'**
  String get bronzeFirst;

  /// No description provided for @stageTieBreak.
  ///
  /// In en, this message translates to:
  /// **'Stage tie-break'**
  String get stageTieBreak;

  /// No description provided for @groupTieBreak.
  ///
  /// In en, this message translates to:
  /// **'Group tie-break'**
  String get groupTieBreak;

  /// No description provided for @semifinalBout.
  ///
  /// In en, this message translates to:
  /// **'Semifinal'**
  String get semifinalBout;

  /// No description provided for @bronzeBout.
  ///
  /// In en, this message translates to:
  /// **'Bronze match'**
  String get bronzeBout;

  /// No description provided for @goldBout.
  ///
  /// In en, this message translates to:
  /// **'Gold/Silver final'**
  String get goldBout;

  /// No description provided for @eliminationRound.
  ///
  /// In en, this message translates to:
  /// **'Elimination round'**
  String get eliminationRound;

  /// No description provided for @scanPairingQr.
  ///
  /// In en, this message translates to:
  /// **'Scan pairing QR'**
  String get scanPairingQr;

  /// No description provided for @pairingLink.
  ///
  /// In en, this message translates to:
  /// **'One-time pairing link'**
  String get pairingLink;

  /// No description provided for @usePairingLink.
  ///
  /// In en, this message translates to:
  /// **'Use pairing link'**
  String get usePairingLink;

  /// No description provided for @manualConnection.
  ///
  /// In en, this message translates to:
  /// **'Manual URL + device token'**
  String get manualConnection;

  /// No description provided for @pairingIntro.
  ///
  /// In en, this message translates to:
  /// **'Ask the organizer for a one-time QR. Review the server address before connecting.'**
  String get pairingIntro;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera scanning is unavailable or permission was denied. Use the pairing link or manual connection below.'**
  String get cameraUnavailable;

  /// No description provided for @invalidPairingQr.
  ///
  /// In en, this message translates to:
  /// **'Invalid pairing QR. Ask for a current Opossum one-time pairing code and an HTTPS server.'**
  String get invalidPairingQr;

  /// No description provided for @pairingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Connect to this Opossum server?'**
  String get pairingConfirm;

  /// No description provided for @repairEvidenceNotice.
  ///
  /// In en, this message translates to:
  /// **'Re-pairing does not delete saved scores or confirmed operations. Requests tied to the old credential will not be reassigned to a new token: review them with the organizer. An expired, used or uncertain pairing needs a new QR.'**
  String get repairEvidenceNotice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
