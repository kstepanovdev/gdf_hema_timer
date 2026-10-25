// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Табло';

  @override
  String get reset => 'Скинути';

  @override
  String get start => 'СТАРТ';

  @override
  String get stop => 'Стоп';

  @override
  String get warning => 'Зауваження';

  @override
  String get caution => 'Попередження';

  @override
  String get double => 'Обопільні';

  @override
  String get helpTitle => 'Як користуватися';

  @override
  String get helpTap => 'Торкніться числа, щоб додати очко.';

  @override
  String get helpLongPress => 'Утримуйте число, щоб зняти очко.';

  @override
  String get helpTimer => 'Утримуйте таймер, щоб змінити час раунду.';

  @override
  String get helpLog =>
      'Потягніть панель журналу вгору, щоб відкрити журнал бою.';

  @override
  String get helpResetScore =>
      'Утримуйте «Скинути», щоб скинути рахунок (час залишиться).';

  @override
  String get helpSettings =>
      'Проведіть від лівого краю, щоб відкрити налаштування — темна тема, звуки та ця підказка там.';

  @override
  String get dontShowAgain => 'Більше не показувати';

  @override
  String get continueLabel => 'Продовжити';

  @override
  String get settingsTitle => 'Налаштування';

  @override
  String get darkTheme => 'Темна тема';

  @override
  String get yehorsSpecial => 'Спеціально для Єгора';

  @override
  String get yehorsSpecialSubtitle => 'Відтворювати звук при обопільному ударі';

  @override
  String get showTutorial => 'Показати підказку';

  @override
  String get language => 'Мова';

  @override
  String get systemDefault => 'Як у системі';

  @override
  String get selectTime => 'Оберіть час';

  @override
  String get cancel => 'Скасувати';

  @override
  String get ok => 'OK';

  @override
  String minutesLabel(int count) {
    return '$count хв';
  }

  @override
  String secondsLabel(int count) {
    return '$count с';
  }

  @override
  String get secondsShort => 'с';

  @override
  String get dragUpForLogs => 'Потягніть вгору для журналу';

  @override
  String get noEventsYet => 'Поки немає подій';

  @override
  String get logFightStarted => 'Бій розпочато';

  @override
  String logWarningTo(String name) {
    return 'Зауваження для $name';
  }

  @override
  String logCautionTo(String name) {
    return 'Попередження для $name';
  }

  @override
  String get logDoubleHit => 'Обопільний удар';

  @override
  String get standaloneMode => 'Автономний таймер';

  @override
  String get tournamentMode => 'Турнір Opossum';

  @override
  String get standaloneDescription =>
      'Працює офлайн без облікового запису чи сервера. Бої та журнал зберігаються лише в пам’яті; після перезапуску починається новий бій.';

  @override
  String get tournamentDescription =>
      'Підключіться до Opossum, оберіть доступний бій і надішліть підтверджений результат.';

  @override
  String get interruptedClock =>
      'Відлік перервано. Таймер призупинено. Перевірте залишок часу перед повторним запуском.';

  @override
  String get sessionNotRestored =>
      'Новий локальний бій. Після перезапуску попередній рахунок і час не відновлюються.';

  @override
  String get swapSides => 'Поміняти сторони учасників';

  @override
  String get logPaused => 'Таймер призупинено';

  @override
  String get logResumed => 'Таймер продовжено';

  @override
  String get logElapsed => 'Час вичерпано';

  @override
  String get logInterrupted => 'Відлік перервано — потрібна перевірка';

  @override
  String get logTimeAdjusted => 'Залишок часу змінено';

  @override
  String get logSidesSwapped => 'Сторони на екрані поміняно';

  @override
  String get logReset => 'Новий бій — рахунок і санкції скинуто';

  @override
  String get leaveBoutTitle => 'Вийти з бою?';

  @override
  String get leaveBoutMessage =>
      'Локальний бій і його журнал буде втрачено. Дані не надсилаються в Opossum.';

  @override
  String get leaveBout => 'Вийти з бою';

  @override
  String get serverUrl => 'Адреса сервера Opossum';

  @override
  String get deviceToken => 'Токен пристрою';

  @override
  String get testConnection => 'Перевірити та зберегти з’єднання';

  @override
  String get connectionReady => 'З’єднання перевірено';

  @override
  String get chooseTournament => 'Оберіть турнір';

  @override
  String get chooseNomination => 'Оберіть номінацію';

  @override
  String get worklist => 'Робочі призначення';

  @override
  String get refresh => 'Оновити';

  @override
  String get noWork =>
      'Доступних колових боїв немає. Попросіть організатора згенерувати розклад і розпочати групу.';

  @override
  String get noTournaments => 'Для цього токена немає активних номінацій.';

  @override
  String get localHttp =>
      'Дозволити HTTP лише для localhost (локальна розробка)';

  @override
  String get invalidConnection =>
      'Вкажіть адресу HTTPS-сервера й токен пристрою. HTTP потребує явного дозволу для локальної розробки на localhost.';

  @override
  String get secureStorageError =>
      'Захищене сховище недоступне. Розблокуйте або налаштуйте системне сховище ключів і повторіть спробу. Токени не зберігаються відкритим текстом.';

  @override
  String get browserTokenNotice =>
      'Браузер тримає токен лише в пам’яті. Після виходу або перезапуску введіть його знову.';

  @override
  String get onlineOnlyNotice =>
      'Надсилання лише онлайн. Запити зберігаються в пам’яті, а не на диску. Не закривайте екран до підтвердження прийняття; перезапуск може втратити непідтверджений запит.';

  @override
  String get apiAuthentication =>
      'Токен недійсний, прострочений або відкликаний.';

  @override
  String get apiForbidden => 'Токен не має дозволу на цю дію чи призначення.';

  @override
  String get apiConflict =>
      'В Opossum інша версія або пара учасників. Ваш результат не застосовано. Попросіть організатора перевірити його; автоматичну заміну заборонено.';

  @override
  String get apiRejected =>
      'Opossum відхилив результат. Попросіть організатора перевірити бій.';

  @override
  String get apiUnavailable =>
      'Сервер недоступний. Перевірте адресу та з’єднання.';

  @override
  String get apiTimeout =>
      'Підтвердження не отримано вчасно. Запит міг бути прийнятий. Повторіть його з тими самими ідентифікаторами.';

  @override
  String get apiProtocol =>
      'Неочікувана відповідь API. Стан надсилання може бути невідомим; перевірте його перед повторним внесенням результату організатором.';

  @override
  String get apiCancelled => 'Запит скасовано.';

  @override
  String get apiRateLimited =>
      'Забагато запитів. Зачекайте перед повторним надсиланням того самого запиту.';

  @override
  String get reviewResult => 'Переглянути результат';

  @override
  String get confirmSubmit => 'Підтвердити й надіслати';

  @override
  String get retrySubmission => 'Повторити той самий запит';

  @override
  String get resultAccepted => 'Прийнято Opossum';

  @override
  String get duplicateAccepted =>
      'Уже прийнято — підтверджено ідемпотентним повтором';

  @override
  String get acceptedAfterRetry =>
      'Прийнято після повтору (сервер не вказує повторне прийняття)';

  @override
  String get resultPending => 'Не надіслано';

  @override
  String get resultSending => 'Очікується підтвердження Opossum';

  @override
  String get normalResult => 'Звичайний результат';

  @override
  String get drawResult => 'Нічия (NORMAL)';

  @override
  String get returnWorklist => 'Повернутися до призначень';

  @override
  String get refreshFailed =>
      'Результат прийнято, але оновити бій або призначення не вдалося. Оновіть повторно; не надсилайте результат знову.';

  @override
  String get unsupportedHits =>
      'Цей API не підтримує зміну обопільних влучань. Відновіть завантажену кількість або попросіть організатора внести перевірений результат разом із влучаннями.';

  @override
  String get localDiscipline =>
      'Зауваження й попередження на пристрої — лише локальні нотатки. Вони не надсилаються до Opossum.';

  @override
  String get boutUnavailable =>
      'Бій більше недоступний для запису або не підтримується цією першою коловою інтеграцією. Оновіть призначення.';

  @override
  String get leaveConnectedBout =>
      'Відкинути локальну чернетку бою? Непідтверджені зміни не надсилалися до Opossum.';

  @override
  String get currentServerResult => 'Поточний результат на сервері';

  @override
  String get configurationLabel => 'Конфігурація';

  @override
  String get forgetConnection => 'Видалити збережене з’єднання';

  @override
  String get resultUncertain =>
      'Прийняття невідоме — повторіть той самий запит.';

  @override
  String get resultUnconfirmed =>
      'Авторитетного підтвердження прийняття немає.';

  @override
  String get choosePiste => 'Оберіть фізичне ристалище';

  @override
  String get serverRevision => 'Ревізія сервера';

  @override
  String get recommendationHint =>
      'Рекомендація — це запропонований порядок. Можна обрати будь-який доступний бій.';

  @override
  String get recommendedNext => 'Рекомендований наступний бій';

  @override
  String get readyBout => 'Доступний для суддівства';

  @override
  String get activeWork => 'Активно';

  @override
  String get plannedWork => 'Заплановано — ще недоступно';

  @override
  String get completedWork => 'Завершено';

  @override
  String get awaitingSchedule => 'Очікує розкладу';

  @override
  String get waitingStage => 'Очікується початок етапу організатором';

  @override
  String get waitingGroup => 'Очікується початок групи організатором';

  @override
  String get waitingConfiguration =>
      'Очікується активація цієї конфігурації в Opossum';

  @override
  String get waitingOtherPistes => 'Очікуються решта боїв на інших ристалищах';

  @override
  String get unavailableWork =>
      'Недоступно — оновіть або зверніться до організатора';

  @override
  String get cancelledWork => 'Скасовано';

  @override
  String get voidWork => 'Анульовано';

  @override
  String get stageLocked => 'Етап закрито для введення результатів';

  @override
  String get fightersHere => 'Учасники на цьому ристалищі';

  @override
  String get previousConfiguration => 'Попередня конфігурація';

  @override
  String get nextConfiguration => 'Наступна конфігурація';

  @override
  String get previousPopulation => 'Попередній склад';

  @override
  String get currentPopulation => 'Склад цієї конфігурації';

  @override
  String get nextPopulation => 'Наступний склад';

  @override
  String get transitionAuthority =>
      'Групи розпочинає організатор; Opossum активує наступну конфігурацію після завершення всіх боїв поточної.';

  @override
  String get remainingHere => 'Залишилось тут';

  @override
  String get remainingElsewhere =>
      'Залишилось на інших ристалищах у цій конфігурації';

  @override
  String get executionStep => 'Крок';

  @override
  String get otherReadyBout => 'Обрати інший доступний бій?';

  @override
  String get otherReadyExplanation =>
      'Це не рекомендований наступний бій, але Opossum дозволяє його суддівство. Підтвердьте пару з організатором.';

  @override
  String get upcomingWork => 'Поточні й майбутні призначення';

  @override
  String get activeBoutRetained =>
      'Оновлення не замінює цей локальний бій або його учасників. Завершіть або явно залиште його перед зміною ристалища.';

  @override
  String get activeBoutChanged =>
      'В Opossum змінився цей бій або його доступність. Локальну чернетку збережено. Не надсилайте її як новий результат — зверніться до організатора.';

  @override
  String get fightersChanged =>
      'Учасники змінюють ристалища — перевірте поточний склад перед суддівством';

  @override
  String get fightersLeaving => 'Залишають це ристалище';

  @override
  String get fightersArriving => 'Прибувають на це ристалище';

  @override
  String get waitingGroupCompletion =>
      'Бої вирішено — очікується завершення групи організатором';

  @override
  String get waitingTieBreak => 'Очікується вирішення тай-брейку';

  @override
  String get waitingJudgeSheet => 'Очікується закриття суддівського протоколу';

  @override
  String get savedOnDevice =>
      'Збережено на пристрої — очікується підтвердження Opossum.';

  @override
  String get draftSavedOnDevice => 'Чернетку збережено на пристрої';

  @override
  String get savingLocally => 'Збереження на пристрої…';

  @override
  String get durableModeNotice =>
      'Рахунки й підтверджені результати зберігаються на пристрої. Результат стає офіційним лише після підтвердження Opossum.';

  @override
  String get durableStorageError =>
      'Локальне сховище недоступне або сталася помилка збереження. Залиште екран відкритим і повторіть спробу. Незбережені зміни ще не захищені.';

  @override
  String get pendingResults => 'Результати для синхронізації';

  @override
  String get pendingLeaveWarning =>
      'Непідтверджені сервером результати залишаться на пристрої. Вихід або зміна призначення їх не видаляє. Для синхронізації поверніться з тим самим сервером і початковим ключем пристрою. Кількість:';

  @override
  String get openSavedOffline => 'Відкрити збережений турнір офлайн';

  @override
  String get offlineMode => 'Офлайн / збережені призначення';

  @override
  String get cachedWorkWarning =>
      'Це збережений стан сервера. Доступність могла змінитися. Можна обрати лише раніше доступні бої; майбутні конфігурації не активуються локально. Після відновлення зв’язку Opossum перевірить кожен підтверджений результат.';

  @override
  String get resumeSavedBout => 'Відновити збережену чернетку бою';

  @override
  String get recoveredClockNotice =>
      'Відновлено на паузі з останнім збереженим часом. Час після переривання невідомий. Перевірте й за потреби скоригуйте таймер перед продовженням; рахунки та учасників збережено.';

  @override
  String get leaveSavedBout =>
      'Залишити цей бій? Збережена чернетка залишиться на пристрої. Непідтверджені рахунки не надсилалися як офіційний результат.';

  @override
  String get outboxExplanation =>
      'Локальні результати зберігаються з початковими ідентифікаторами запиту. Конфлікти потрібно розглядати на столі організатора; пристрій не перезаписує чужий результат.';

  @override
  String get reconnectForSync =>
      'Для синхронізації підключіться з початковим ключем пристрою. Новий ключ не може безпечно повторити запит із невідомим результатом.';

  @override
  String get handledAtDesk => 'Опрацьовано на столі організатора';

  @override
  String get handledExplanation =>
      'Підтверджуйте лише після розгляду результату організатором. Буде збережено локальну відмітку та всі дані; рахунки Opossum не зміняться, виправлення не буде автоматично схвалене.';

  @override
  String get reviewReason => 'Причина рішення';

  @override
  String get confirmReview => 'Підтвердити розглянуте рішення';

  @override
  String get syncReason => 'Причина стану синхронізації';

  @override
  String get dependencyNotice =>
      'Цей запис очікує підтвердження обов’язкових попередніх операцій.';

  @override
  String get browserPersistenceNotice =>
      'Сховище браузера не захищене від автоматичного очищення. Не очищуйте дані сайту та не користуйтеся приватним режимом, поки є ненадіслані результати. Збережіть початковий токен пристрою для відновлення.';

  @override
  String get retryPausedNotice =>
      'Автоматичні повторні спроби призупинено після кількох невдач. Результат збережено. Перевірте з’єднання та повторіть надсилання вручну.';

  @override
  String get judgingTitle => 'Офіційне суддівство';

  @override
  String get judgeRemark => 'Зауваження';

  @override
  String get judgeWarning => 'Попередження';

  @override
  String get judgeMutualHit => 'Обопільні влучання';

  @override
  String get judgingPending => 'Очікують підтвердження (ще не офіційні)';

  @override
  String get judgingConfirm => 'Підтвердити фактичну суддівську дію';

  @override
  String get judgingConfirmExplanation =>
      'Підтверджуйте лише дію, що справді відбулася. Спортивні наслідки визначає Opossum.';

  @override
  String judgingPolicy(int remarks, int warnings) {
    return 'Чинне правило: $remarks зауважень на попередження; $warnings попереджень до дискваліфікації.';
  }

  @override
  String judgingHitPolicy(int threshold, String action) {
    return 'Обопільні: поріг $threshold · $action';
  }

  @override
  String judgingRefight(int attempt) {
    return 'Перебій · спроба $attempt';
  }

  @override
  String get judgingSuddenDeath => 'До першого чистого вирішального влучання';

  @override
  String get judgingStandard => 'Звичайний бій';

  @override
  String get judgingDoubleLoss => 'Подвійна поразка — підтверджено Opossum';

  @override
  String get judgingDisqualified => 'Дискваліфіковано — підтверджено Opossum';

  @override
  String get judgingReview =>
      'Прийняті суддівські записи виправляє організатор. Офіційні лічильники не можна зменшувати на таймері.';

  @override
  String get judgingHistory => 'Офіційна суддівська історія';

  @override
  String get judgingUnavailable =>
      'Офіційне суддівство недоступне. Локальні санкції в режимі турніру вимкнено.';

  @override
  String get judgingNoScope =>
      'Цей ключ не дозволяє суддівські дії. Зверніться до організатора по відповідний доступ.';

  @override
  String get judgingOffline =>
      'Без мережі дії залишаються локальними свідченнями. Офіційний лічильник і продовження бою невідомі до підтвердження Opossum.';

  @override
  String get judgingWaitResult =>
      'Перед підтвердженням результату синхронізуйте або узгодьте суддівські дії. Рахунок зберігається на пристрої.';

  @override
  String get judgingCancelLocal => 'Скасувати ненадіслану дію';

  @override
  String get judgingCancelledLocal => 'Скасовано до надсилання (не офіційно)';

  @override
  String get judgingAccepted => 'Офіційний стан від Opossum';

  @override
  String get judgingRecordVoided => 'Скасовано організатором';

  @override
  String judgingScoreSnapshot(int scoreA, int scoreB) {
    return 'Поточний рахунок для підтвердження: $scoreA:$scoreB';
  }

  @override
  String get judgingDisabledPolicy => 'Вимкнено правилами етапу';

  @override
  String get judgingDoubleLossPolicy => 'Подвійна поразка';

  @override
  String get judgingRefightPolicy => 'Перебої';

  @override
  String get judgingHybridPolicy => 'Перебої, потім до чистого влучання';

  @override
  String get judgingSyncBlocked =>
      'Суддівські дії потребують розгляду організатором; локальні свідчення збережені.';

  @override
  String get judgingContinuationTitle => 'Перегляньте підтверджене продовження';

  @override
  String get judgingContinuationReview =>
      'Opossum підтвердив нову спробу. Час призупинено, попередній локальний рахунок збережено. Перегляньте його перед очищенням чернетки для нової спроби.';

  @override
  String get judgingStartAttempt => 'Почати підтверджену спробу';

  @override
  String get judgingResultReview =>
      'Суддівські дії синхронізуються окремо. Цей рахунок стає офіційним лише після прийняття результату Opossum.';

  @override
  String get judgingScoresRequired =>
      'Для цього влучання потрібні обидва поточні рахунки. Їх атомарне надсилання також потребує доступу до запису результатів; інакше зверніться до організатора.';

  @override
  String get operationalBouts => 'Олімпійські бої та перебої';

  @override
  String get operationalSelection => 'Обрати бій без резервування?';

  @override
  String get operationalWarning =>
      'Вибір зберігається лише на цьому пристрої та не резервує бій. Перед боєм узгодьте призначення з організатором: інший таймер може обрати той самий бій. Новий результат або зміна пари потребують розгляду на столі; локальні дані зберігаються.';

  @override
  String get unassignedPiste => 'Ристалище не призначено';

  @override
  String get automaticWin =>
      'Автоматична перемога — без бою та числового результату';

  @override
  String get bronzeFirst => 'Спочатку завершіть бій за бронзу';

  @override
  String get stageTieBreak => 'Перебій етапу';

  @override
  String get groupTieBreak => 'Перебій групи';

  @override
  String get semifinalBout => 'Півфінал';

  @override
  String get bronzeBout => 'Бій за бронзу';

  @override
  String get goldBout => 'Фінал за золото та срібло';

  @override
  String get eliminationRound => 'Раунд олімпійської сітки';

  @override
  String get scanPairingQr => 'Сканувати QR сполучення';

  @override
  String get pairingLink => 'Одноразове посилання сполучення';

  @override
  String get usePairingLink => 'Використати посилання';

  @override
  String get manualConnection => 'URL і токен пристрою вручну';

  @override
  String get pairingIntro =>
      'Попросіть одноразовий QR в організатора. Перед підключенням перевірте адресу сервера.';

  @override
  String get cameraUnavailable =>
      'Камера недоступна або дозвіл відхилено. Скористайтеся посиланням сполучення або введіть дані вручну.';

  @override
  String get invalidPairingQr =>
      'Непридатний QR. Попросіть чинний одноразовий код Opossum та HTTPS-сервер.';

  @override
  String get pairingConfirm => 'Підключитися до цього сервера Opossum?';

  @override
  String get repairEvidenceNotice =>
      'Повторне сполучення не видаляє збережені рахунки й підтверджені операції. Запити старого токена не надсилатимуться з новим: узгодьте їх з організатором. Для простроченого, використаного або непевного сполучення потрібен новий QR.';
}
