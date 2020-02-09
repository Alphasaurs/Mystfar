const cache = require('./common/node/cache');

module.exports = {
  loadLang: require('./loadLang')({
    gunzip: require('./common/node/gunzip'),
    ...cache,
  }),
  readImage: require('./readImage'),
  cache,
};
