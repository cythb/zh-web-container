
/**
 *
 *
 * @param {*} text
 */
var outputText = ''
function log(text) {
    console.log(text);
    outputText += text + '<br/>'
    document.getElementById('output').innerHTML = outputText;
}

/** Class representing a point. */
class Native {
    constructor() {
        // 保存需要长期存在的回调
        this._cbs = {}
        // 通过eventId来与iOS关联，一旦ios执行完成，通过eventId来查找回调方法。找到方法之后运行并删除event。
        this._events = {}
    }

    /**
     *
     *
     * @return {*}  {string}
     * @memberof Native
     */
    hello() {
        console.log('hello');
        document.getElementById('output').innerHTML = 'hello';
        return 'hello';
    }

    /**
     * 注册监听事件, 事件完成之后会调用`callback`方法。
     * 
     * 回调时会传入text参数
     *
     * @param {function} callback 
     * @param {string} text
     * @memberof Native
     */
    onTest(callback) {
        this._cbs['onTest'] = callback
    }

    /**
     * 取消注册监听事件
     *
     * @memberof Native
     */
    offTest() {
        f = this._cbs.onTest
        if (f == undefined) {
            return
        }
        delete this._cbs.onTest
    }

    uuid() {
        var s = [];
        var hexDigits = "0123456789abcdef";
        for (var i = 0; i < 36; i++) {
            s[i] = hexDigits.substr(Math.floor(Math.random() * 0x10), 1);
        }
        s[14] = "4";  // bits 12-15 of the time_hi_and_version field to 0010
        s[19] = hexDigits.substr((s[19] & 0x3) | 0x8, 1);  // bits 6-7 of the clock_seq_hi_and_reserved to 01
        s[8] = s[13] = s[18] = s[23] = "_";

        var uuid = '_' + s.join("");
        return uuid;
    }

    /**
     * ios执行完成之后会调用该方法来执行对应事件的回调
     *
     * @param {string} eventId
     * @param {bool} isSuccess
     * @param {object} data
     * @memberof Native
     */
    done(eventId, isSuccess, data) {
        let k = this._events[eventId]
        if (k == undefined) {
            return
        }

        if (isSuccess) {
            k.success(data)
            delete this._events[eventId]
        } else {
            k.fail(data)
            delete this._events[eventId]
        }
        k.complete()
    }

    progress(eventId, percent) {
        let k = this._events[eventId]
        if (k == undefined) {
            return
        }

        let p = k.progress 
        if (p == undefined) {
            return
        }

        p(percent)
    }

    /**
     * 关闭所有页面，打开到应用内的某个页面
     *
     * @param {string} url 需要跳转的应用内页面路径 (代码包路径)，路径后可以带参数。参数与路径之间使用?分隔，参数键与参数值用=相连，不同参数用&分隔；如 'path?key=value&key2=value2'
     * @param {function} success(object) 接口调用成功的回调函数。
     * @param {function} fail(object) 接口调用失败的回调函数
     * @param {function} complete 接口调用结束的回调函数（调用成功、失败都会执行）
     * @memberof Native
     */
    reLaunch(url, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {url: url, eventId: eventId}
        window.webkit.messageHandlers.reLaunch.postMessage(msg);
    }

    takePhoto(sourceType, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {sourceType: sourceType, eventId: eventId}
        window.webkit.messageHandlers.takePhoto.postMessage(msg);
    }

    chooseImage(sourceType, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {sourceType: sourceType, eventId: eventId}
        window.webkit.messageHandlers.chooseImage.postMessage(msg);
    }
    
    scanCode(onlyFromCamera, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {onlyFromCamera: onlyFromCamera, eventId: eventId}
        window.webkit.messageHandlers.scanCode.postMessage(msg);
    }

    getFileList(path, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {path: path, eventId: eventId}
        window.webkit.messageHandlers.getFileList.postMessage(msg);
    }

    rmFile(path, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {path: path, eventId: eventId}
        window.webkit.messageHandlers.rmFile.postMessage(msg);
    }

    unzip(zipFilePath, targetPath, success, fail, complete, progress) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete,
            'progress': progress
        }

        let msg = {zipFilePath: zipFilePath, targetPath: targetPath, eventId: eventId}
        window.webkit.messageHandlers.unzip.postMessage(msg);
    }

    downloadFile(url, filePath, success, fail, complete, progress) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete,
            'progress': progress
        }

        let msg = {url: url, filePath: filePath, eventId: eventId}
        window.webkit.messageHandlers.downloadFile.postMessage(msg);
    }

    uploadFile(url, filePath, name, formData, success, fail, complete, progress) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete,
            'progress': progress
        }

        let msg = {url: url, filePath: filePath, name: name, formData: formData, eventId: eventId}
        window.webkit.messageHandlers.uploadFile.postMessage(msg);
    }

    openSqlite(file, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {file: file, eventId: eventId}
        window.webkit.messageHandlers.openSqlite.postMessage(msg);
    }

    closeSqlite(success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {eventId: eventId}
        window.webkit.messageHandlers.closeSqlite.postMessage(msg);
    }

    executeUpdate(sql, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {sql: sql, eventId: eventId}
        window.webkit.messageHandlers.executeUpdate.postMessage(msg);
    }

    executeQuery(sql, success, fail, complete) {
        let eventId = this.uuid()
        this._events[eventId] = {
            'success': success,
            'fail': fail,
            'complete': complete
        }

        let msg = {sql: sql, eventId: eventId}
        window.webkit.messageHandlers.executeQuery.postMessage(msg);
    }
}
const native = new Native();

// native.onTest( (data) => {
//     log(data)
// })

// setInterval(function() {
//     f = native._cbs.onTest
//     if (f == undefined) {
//         return
//     }
//     native._cbs.onTest('test onText')
//     native.offTest()
// }, 3000)
