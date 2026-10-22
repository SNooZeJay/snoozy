/** @type {import('jest').Config} */
module.exports = {
  preset: 'jest-expo',
  testPathIgnorePatterns: ['/node_modules/', '/reference/', '/android/', '/ios/'],
  modulePathIgnorePatterns: ['<rootDir>/reference/', '<rootDir>/android/', '<rootDir>/ios/'],
};
