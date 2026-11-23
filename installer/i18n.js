
module.exports = (function () {

    const translations = require('./assets/i18n.json');
    var local = 'en';

    function setLang(lang = '') {
        local = lang;
    }

    function getLang() {
        return local;
    }

    function l(text) {
        let txt;
        if (!translations[local] && !(txt = translations[local][text])) {
            return text;
        }
        return txt;
    }

    return {
        setLang,
        getLang,
        l
    };

})()