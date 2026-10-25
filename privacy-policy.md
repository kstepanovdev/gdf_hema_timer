**Privacy Policy**

This privacy policy applies to the GDF HEMA Timer app (hereby referred to as "Application") for mobile devices that was created by Kyrylo Stepanov (hereby referred to as "Service Provider") as an Open Source service. This service is intended for use "AS IS".

**What information does the Application obtain and how is it used?**

Standalone mode needs no account or internet connection and sends no bout data to a server. Its scores and fight log stay in memory. Duration, language, theme and sound preferences are stored on the device.

If you explicitly select Opossum Tournament mode, the Application connects to the Opossum server you configure. It reads authorized tournament, nomination, assignment and fighter names/identifiers. Only after your confirmation does it send the bout identifier, A/B scores, result type, expected pairing/version, request identifiers, random device identifier and submission timestamp. Opossum keeps its existing sporting records and audit trail. Timer clock readings, local disciplinary notes and unconfirmed score drafts are not transmitted.

Device tokens are kept in OS-backed secure storage where supported. Browser tokens remain in memory only and are not saved to browser storage. The server URL and random device identifier are non-secret configuration. Tournament mode stores paired fighter names/IDs, cached schedules, score/control history, session recovery checkpoints, confirmed requests, retry/conflict evidence and server acknowledgements in local SQLite (IndexedDB-backed SQLite in supported browsers). Tokens remain separate; only a non-reversible credential fingerprint is stored with the queue. Confirmed requests remain on the device until acknowledged or explicitly reviewed at the organizer desk; historical evidence is retained. Leaving tournament mode or forgetting a token does not delete this local sporting data. Uninstalling, clearing site data, private browsing or browser storage eviction can remove local data; a warning appears if browser eviction protection is unavailable. Protect access to the device and retain the original credential for reconnecting.

**Does the Application collect precise real time location information of the device?**

This Application does not collect precise information about the location of your mobile device.

**Do third parties see and/or have access to information obtained by the Application?**

Standalone mode shares no sporting data. In connected mode, confirmed results and device audit identifiers go only to the selected Opossum server, where its administrators and authorized users may access them under that server’s rules. This app does not introduce advertising or analytics services.

**What are my opt-out rights?**

You can stop all collection of information by the Application easily by uninstalling it. You may use the standard uninstall processes as may be available as part of your mobile device or via the mobile application marketplace or network.

**Children**

The Application is not used to knowingly solicit data from or market to children under the age of 13.

The Service Provider does not knowingly collect personally identifiable information from children. The Service Provider encourages all children to never submit any personally identifiable information through the Application and/or Services. The Service Provider encourage parents and legal guardians to monitor their children's Internet usage and to help enforce this Policy by instructing their children never to provide personally identifiable information through the Application and/or Services without their permission. If you have reason to believe that a child has provided personally identifiable information to the Service Provider through the Application and/or Services, please contact the Service Provider (kyrylo.stepanov@gmail.com) so that they will be able to take the necessary actions. You must also be at least 16 years of age to consent to the processing of your personally identifiable information in your country (in some countries we may allow your parent or guardian to do so on your behalf).

**Security**

Connected mode uses HTTPS with certificate validation, bearer authentication and version/pairing guards. Redirects are refused. An explicit local-development option allows HTTP only on loopback hosts; do not use that exception for a remote tournament server. Tokens are not intentionally logged or stored in plain shared preferences. Secure storage and device access remain subject to the operating system’s protections.

**Changes**

This Privacy Policy may be updated from time to time for any reason. The Service Provider will notify you of any changes to their Privacy Policy by updating this page with the new Privacy Policy. You are advised to consult this Privacy Policy regularly for any changes, as continued use is deemed approval of all changes.

This privacy policy is effective as of 2026-10-24

**Your Consent**

By using the Application, you are consenting to the processing of your information as set forth in this Privacy Policy now and as amended by the Service Provider.

**Contact Us**

If you have any questions regarding privacy while using the Application, or have questions about the practices, please contact the Service Provider via email at kyrylo.stepanov@gmail.com.

* * *

This privacy policy page was generated by [App Privacy Policy Generator](https://app-privacy-policy-generator.nisrulz.com/)

**Optional QR pairing and authoritative judging**

Camera access is used only after selecting Scan QR on supported native platforms.
Frames are decoded locally; they are not saved, uploaded or used for analytics.
The scanned one-time code and random device ID are sent only to the HTTPS origin
you explicitly confirm, to obtain a scoped device credential. The code is not a
reusable token. Manual setup remains available without camera permission. Web
loads no third-party scanner and uses manual setup.

Confirmed tournament remarks, warnings and mutual hits (including an authorized
current-score snapshot when needed) are sent to that Opossum server and retained
in its sporting audit. Unaccepted events stay labelled local pending evidence.
No standalone penalties become official records. Re-pairing preserves pending
local evidence but does not authorize replay under a new credential. Administrators
can revoke credentials on the server; device data is not remotely deleted.
