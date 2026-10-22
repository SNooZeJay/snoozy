/**
 * Expo Router lists react-native-gesture-handler as an optional peer. This app
 * only uses the native stack, so its gesture-handler codegen is neither needed
 * nor buildable on this Windows workspace (the generated C++ object path
 * exceeds the legacy 260-character limit).
 *
 * Exclude the native project from React Native autolinking. The JS package
 * remains installed for Expo Router's optional drawer exports.
 */
module.exports = {
  dependencies: {
    'react-native-gesture-handler': {
      platforms: {
        android: null,
      },
    },
  },
};
