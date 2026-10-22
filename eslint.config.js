const { defineConfig } = require('eslint/config');
const expoConfig = require('eslint-config-expo/flat');

module.exports = defineConfig([
  expoConfig,
  {
    ignores: ['reference/**', 'android/**', 'ios/**', 'node_modules/**', 'dist/**'],
  },
]);
