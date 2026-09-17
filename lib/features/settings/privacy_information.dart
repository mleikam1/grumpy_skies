import 'package:flutter/material.dart';

Future<void> showPrivacyInformation(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy information'),
        content: const SingleChildScrollView(
            child: Text(
                'Your selected location is used by the existing weather backend. Device location requires permission; manual search is available. Weather and preferences may be cached locally.\n\n'
                'Meme photos, captions, and projects stay in the local studio store. Share and export send content only to the destination you choose. Back up projects before clearing storage or uninstalling.\n\n'
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
