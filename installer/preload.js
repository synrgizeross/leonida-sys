const { contextBridge, ipcRenderer } = require('electron')

function news() {
  return call('news')
}

function shopArticles() {
  return call('shopArticles')
}

function info() {
  return call('info')
}

function apply(version) {
  return call('apply', version)
}

function call(...args) {
  return ipcRenderer.invoke(...args)
}

function on(eventName, listener) {
  return ipcRenderer.on(eventName, listener);
}

const clientApi = {
  info,
  news,
  apply,
  shopArticles,
  call,
  on
};

contextBridge.exposeInMainWorld('services', clientApi);