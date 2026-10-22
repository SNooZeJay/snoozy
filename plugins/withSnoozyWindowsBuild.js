const { withAppBuildGradle } = require('expo/config-plugins');

/**
 * Windows' legacy path limit applies to generated CMake object directories.
 * Stage this app's C++ build in a short, stable directory so the generated
 * codegen paths stay below MAX_PATH. This only affects local Windows builds;
 * EAS/Linux builds keep the default staging directory.
 */
module.exports = function withSnoozyWindowsBuild(config) {
  if (process.platform !== 'win32') {
    return config;
  }

  return withAppBuildGradle(config, (gradleConfig) => {
    if (gradleConfig.modResults.language !== 'groovy') {
      return gradleConfig;
    }

    const contents = gradleConfig.modResults.contents;
    if (contents.includes('buildStagingDirectory')) {
      return gradleConfig;
    }

    const marker = /(\n    androidResources \{[\s\S]*?\n    \})/;
    if (!marker.test(contents)) {
      throw new Error(
        'withSnoozyWindowsBuild: could not find androidResources in app/build.gradle',
      );
    }

    gradleConfig.modResults.contents = contents.replace(
      marker,
      `$1\n    externalNativeBuild {\n        cmake {\n            buildStagingDirectory "C:/b"\n        }\n    }`,
    );

    return gradleConfig;
  });
};
