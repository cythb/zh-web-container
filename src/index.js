class Native {
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
}
const native = new Native();
