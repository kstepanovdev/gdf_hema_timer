import '../../l10n/gen/app_localizations.dart';
import 'api_client.dart';

String apiErrorMessage(OpossumException error, AppLocalizations l10n) =>
    switch (error.kind) {
      ApiFailure.storage => l10n.secureStorageError,
      ApiFailure.localPersistence => l10n.durableStorageError,
      ApiFailure.authentication => l10n.apiAuthentication,
      ApiFailure.forbidden => l10n.apiForbidden,
      ApiFailure.conflict => l10n.apiConflict,
      ApiFailure.rejected => l10n.apiRejected,
      ApiFailure.unavailable => l10n.apiUnavailable,
      ApiFailure.timeout => l10n.apiTimeout,
      ApiFailure.protocol => l10n.apiProtocol,
      ApiFailure.cancelled => l10n.apiCancelled,
      ApiFailure.rateLimited => l10n.apiRateLimited,
    };
