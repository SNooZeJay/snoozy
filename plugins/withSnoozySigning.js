const { withAppBuildGradle } = require('@expo/config-plugins');

/**
 * Adds a release signing config sourced from the environment. The keystore
 * itself stays outside the repository and is never copied into it.
 */
module.exports = function withSnoozySigning(config) {
  return withAppBuildGradle(config, (config) => {
    let contents = config.modResults.contents;

    const signingMarker = '    signingConfigs {\n        debug {';
    const signingReplacement = `    signingConfigs {
        release {
            def snoozyStoreFile = System.getenv("SNOOZY_KEYSTORE_FILE")
            if (snoozyStoreFile) {
                storeFile file(snoozyStoreFile)
                storePassword System.getenv("SNOOZY_KEYSTORE_PASSWORD")
                keyAlias System.getenv("SNOOZY_KEY_ALIAS")
                keyPassword System.getenv("SNOOZY_KEY_PASSWORD")
            }
        }
        debug {`;

    if (!contents.includes(signingMarker)) {
      throw new Error('Unable to find signingConfigs block in android/app/build.gradle');
    }
    contents = contents.replace(signingMarker, signingReplacement);

    const releaseMarker = `        release {
            // Caution! In production, you need to generate your own keystore file.
            // see https://reactnative.dev/docs/signed-apk-android.
            signingConfig signingConfigs.debug`;
    const releaseReplacement = `        release {
            if (System.getenv("SNOOZY_KEYSTORE_FILE")) {
                signingConfig signingConfigs.release
            } else {
                signingConfig signingConfigs.debug
            }`;

    if (!contents.includes(releaseMarker)) {
      throw new Error('Unable to find release buildType block in android/app/build.gradle');
    }
    contents = contents.replace(releaseMarker, releaseReplacement);

    config.modResults.contents = contents;
    return config;
  });
};
