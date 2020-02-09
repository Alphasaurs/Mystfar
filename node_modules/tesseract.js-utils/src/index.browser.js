const cache = require('./common/browser/cache');

module.exports = {
  loadLang: require('./loadLang')({
    gunzip: require('./common/browser/gunzip'),
    ...cache,
  }),
  readImage: require('./readImage'),
  cache,
};
