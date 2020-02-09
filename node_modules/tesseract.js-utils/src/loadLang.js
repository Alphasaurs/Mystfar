const isURL = require('is-url');
const fileType = require('file-type');
const axios = require('axios');

const handleLang = modules => ({
  TessModule,
  dataPath,
  cachePath,
  cacheMethod,
  langCode,
}) => (data) => {
  if (TessModule) {
    if (dataPath) {
      try {
        TessModule.FS.mkdir(dataPath);
      } catch (err) {
        // TODO: Do some error handling here.
      }
    }
    TessModule.FS.writeFile(`${dataPath || '.'}/${langCode}.traineddata`, data);
  }
  if (['write', 'refresh', undefined].includes(cacheMethod)) {
    return modules.writeCache(`${cachePath || '.'}/${langCode}.traineddata`, data)
      .then(() => data);
  }

  return data;
};

const loadAndGunzipFile = modules => ({
  langPath,
  cachePath,
  cacheMethod,
  gzip = true,
  ...options
}) => (lang) => {
  const langCode = typeof lang === 'string' ? lang : lang.code;
  const handleTraineddata = (data) => {
    const type = fileType(data);
    if (type !== null && type.mime === 'application/gzip') {
      return modules.gunzip(new Uint8Array(data));
    }
    return new Uint8Array(data);
  };
  const doHandleLang = handleLang(modules)({
    cachePath, cacheMethod, langCode, ...options,
  });
  let { readCache } = modules;

  if (['refresh', 'none'].includes(cacheMethod)) {
    readCache = () => Promise.resolve();
  }

  return readCache(`${cachePath || '.'}/${langCode}.traineddata`)
    .then((data) => {
      if (typeof data === 'undefined') {
        return Promise.reject();
      }
      return doHandleLang(data);
    })
    /*
     * If not found in the cache
     */
    .catch(() => {
      if (typeof lang === 'string') {
        const fetchTrainedData = iLangPath => (
          axios.get(`${iLangPath}/${langCode}.traineddata${gzip ? '.gz' : ''}`, {
            responseType: 'arraybuffer',
          })
            .then(({ data }) => new Uint8Array(data))
            .then(handleTraineddata)
            .then(doHandleLang)
        );

        /** When langPath is an URL, just do the fetch */
        if (isURL(langPath) || langPath.startsWith('chrome-extension://')/* for chrome extensions */) {
          return fetchTrainedData(langPath);
        }

        /** When langPath is not an URL in Node.js environment */
        return modules.readCache(`${langPath}/${langCode}.traineddata${gzip ? '.gz' : ''}`)
          .then(handleTraineddata)
          .then(doHandleLang);
      }

      return Promise
        .resolve(lang.data)
        .then(handleTraineddata)
        .then(doHandleLang);
    });
};

/**
 *
 * @name loadLang
 * @function load language(s) from local cache, download from remote if not in cache.
 * @param {object}   options
 * @param {array}    options.langs -
 *     langs to load.
 *     Each item in the array can be string (ex. 'eng') or object like:
 *      {
 *        code: 'eng',
 *        gzip: false,
 *        data: Uint8Array
 *      }
 * @param {object}   options.TessModule - TesseractModule
 * @param {string}   options.langPath - prefix path for downloading lang file
 * @param {string}   options.cachePath - path to find cache
 * @param {string}   options.dataPath - path to store data in mem
 * @param {boolean}  options.gzip -
 *     indicate whether to download gzip version from remote, default: true
 * @param {string} options.cacheMethod -
 *     method of cache invaliation, should one of following options:
 *       write: read cache and write back (default method)
 *       readOnly: read cache and not to write back
 *       refresh: not to read cache and write back
 *       none: not to read cache and not to write back
 *
 */
module.exports = modules => ({
  langs,
  ...options
}) => (
  Promise
    .all((typeof langs === 'string' ? langs.split('+') : langs).map(loadAndGunzipFile(modules)(options)))
);
