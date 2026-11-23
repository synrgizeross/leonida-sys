const { app } = require('electron')

const Exit = (function exit() {
    var isSignaled = false, isExiting;

    var SHUTDOWN_SIGNALS = ['SIGINT', 'SIGTERM'];
    var shutdownListeners = [];

    process.stdin.resume();

    const processOnce = (signals, fn) => {
        return signals.forEach(sig => {
            process.on(sig, fn.bind(null, sig));
        });
    };

    async function shutdownHandler(error) {
        if (!isSignaled) {
            const graceful = () => {
                if (!isExiting) {
                    isExiting = true;
                    process.exit(0);
                }
            }
            const promises = [...shutdownListeners].map((f, i) => f(error));
            Promise.allSettled(promises).then(graceful);
            isSignaled = true;
            return;
        }
        console.warn(`[${process.pid}] re-existing system prevented`)
    }

    processOnce(SHUTDOWN_SIGNALS, shutdownHandler);

    function addListener(listener, clearAll) {
        clearAll && (shutdownListeners = [])
        shutdownListeners.push(listener);
        return listener;
    };

    Object.defineProperty(addListener, 'isSignaled', {
        get: function () {
            return isSignaled;
        }
    });

    addListener.shutdownHandler = shutdownHandler;
    addListener.clear = function () {
        shutdownListeners = [];
    };

    process.once('uncaughtException', shutdownHandler);
    process.once('unhandledRejection', shutdownHandler);

    app && app.on('before-quit', () => shutdownHandler());

    if (typeof process.env.STOP_TIME_MIN == 'number') {
        setTimeout(shutdownHandler, process.env.STOP_TIME_MIN * 60 * 1000)
    }

    return addListener;
})()


module.exports = Exit;