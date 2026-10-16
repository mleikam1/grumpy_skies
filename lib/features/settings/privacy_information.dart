import 'package:flutter/material.dart';

Future<void> showPrivacyInformation(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy information'),
        content: const SingleChildScrollView(
            child: Text(
                'Your selected location is used by the existing weather backend. Device location requires permission; manual search is available. Weather and preferences may be cached locally.\n\n'
                'Meme photos, captions, and projects stay in the local studio store. Share and export send content only to the destination you choose. Back up projects before clearing storage or uninstalling.\n\n'
                'PlanCast is optional and reads only selected device calendars on Android and iOS. It never modifies calendar events. Calendar titles and timing are processed on this device, with necessary choices and venue overrides in protected local storage. Only venue search text or coordinates go to the existing geocoding/weather services; calendar titles, descriptions, guests, and meeting contents are never uploaded or used for advertising.\n\n'
                'PlanCast notifications require separate permission and hide private titles by default. Spoken briefings start only when requested and use an available offline device voice. Scheduled notices are not a guarantee of fresh weather at delivery; background work is best-effort. Disconnect deletes this feature’s data and cancels its notices. Revoked permission is detected when the app can next execute.\n\n'
                'Advertising is disabled by default in this development build. Enabled mobile test builds use Google Mobile Ads and UMP privacy choices. Ad requests do not contain your coordinates, photos, captions, or documents. The SDK may process network, device, advertising, and diagnostic information. Non-personalized advertising does not bypass consent.\n\n'
                'Ad privacy choices appear here when required. Apple tracking permission is separate. No analytics uploader or purchases are configured. Local frequency limits and hashed completion identities prevent repeat interstitials. Web ads remain unavailable until an approved provider and consent setup are connected.\n\n'
                'Production privacy contact details, provider disclosures, and store declarations remain subject to publisher verification.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
