const path = require('path');
const { getDefaultConfig } = require('expo/metro-config');

const projectRoot = __dirname;
const config = getDefaultConfig(projectRoot);
const referenceRoot = path.resolve(projectRoot, 'reference');

// Keep the read-only Riff checkout in the workspace but out of Metro's graph.
config.watchFolders = [projectRoot];
config.resolver.blockList = [
  new RegExp(`${referenceRoot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[/\\\\].*`),
  ...(Array.isArray(config.resolver.blockList)
    ? config.resolver.blockList
    : config.resolver.blockList
      ? [config.resolver.blockList]
      : []),
];

module.exports = config;
