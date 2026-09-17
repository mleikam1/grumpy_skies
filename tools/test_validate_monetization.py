import unittest
from validate_monetization import validate

DEMO = 'ca-app-pub-3940256099942544~1458002511'
APP = 'ca-app-pub-1111111111111111~1111111111'

class BuildGateTest(unittest.TestCase):
    def config(self):
        result = {key: 'true' for key in ('DAYMAKER_ADS_ENABLED', 'DAYMAKER_ADS_READY',
            'DAYMAKER_AUDIENCE_DECLARED', 'DAYMAKER_PRIVACY_READY', 'DAYMAKER_REFRESH_DISABLED')}
        result['DAYMAKER_ANDROID_AD_UNITS'] = ','.join(f'ca-app-pub-1111111111111111/{i:010}' for i in range(1,6))
        result['DAYMAKER_IOS_AD_UNITS'] = ','.join(f'ca-app-pub-1111111111111111/{i:010}' for i in range(6,11))
        return result

    def test_disabled_release_safe_metadata(self):
        self.assertEqual(validate({}, 'ios', True, DEMO), [])
        self.assertTrue(validate({}, 'ios', True, ''))
        self.assertTrue(validate({}, 'android', False, 'bad'))

    def test_release_rejects_test_units_flags_metadata_missing_declarations(self):
        valid = self.config()
        self.assertEqual(validate(valid, 'android', True, APP), [])
        self.assertTrue(validate(valid, 'ios', True, DEMO))
        self.assertTrue(validate({**valid, 'DAYMAKER_TEST_ADS': 'true'}, 'ios', True, APP))
        for key in valid:
            self.assertTrue(validate({k:v for k,v in valid.items() if k != key}, 'ios', True, APP) or key == 'DAYMAKER_ADS_ENABLED')
        self.assertTrue(validate({**valid, 'DAYMAKER_IOS_AD_UNITS': valid['DAYMAKER_ANDROID_AD_UNITS']}, 'ios', True, APP))
        self.assertTrue(validate({**valid, 'DAYMAKER_ANDROID_AD_UNITS': 'ca-app-pub-3940256099942544/6300978111'}, 'android', True, APP))

    def test_debug_enabled_requires_explicit_test_mode(self):
        self.assertTrue(validate({'DAYMAKER_ADS_ENABLED':'true'}, 'android', False, DEMO))
        self.assertEqual(validate({'DAYMAKER_ADS_ENABLED':'true','DAYMAKER_TEST_ADS':'true'}, 'android', False, DEMO), [])

if __name__ == '__main__':
    unittest.main()
