var Native = /** @class */ (function () {
    function Native() {
    }

    /**
     * @function hello
     * @description 测试API文档输出
     * @returns {string} 输出'hello'
     */
    Native.prototype.hello = function () {
        console.log('hello');
        return 'hello';
    };
    return Native;
}());
var native = new Native();
