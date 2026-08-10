// DOM/localStorage/JSON 最小 stub，供 cscript 跑真实 app 脚本（ES5 兼容）
if (typeof JSON === 'undefined') { JSON = {}; }
if (!JSON.stringify) {
  JSON.stringify = function (v) {
    if (v === null) return 'null';
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
    if (typeof v === 'string') return '"' + v.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
    if (v instanceof Array) { var a = []; for (var i = 0; i < v.length; i++) { var x = JSON.stringify(v[i]); a.push((x === undefined) ? 'null' : x); } return '[' + a.join(',') + ']'; }
    if (typeof v === 'object') { var k, o = []; for (k in v) { if (typeof v[k] !== 'function') { var s = JSON.stringify(v[k]); if (s !== undefined) o.push(JSON.stringify(k) + ':' + s); } } return '{' + o.join(',') + '}'; }
    return undefined;
  };
}
if (!JSON.parse) { JSON.parse = function (s) { return (new Function('return ' + s))(); }; }
if (!Array.prototype.indexOf) Array.prototype.indexOf = function (x) { for (var i = 0; i < this.length; i++) if (this[i] === x) return i; return -1; };
if (!Array.prototype.map) Array.prototype.map = function (f) { var r = [], i; for (i = 0; i < this.length; i++) r.push(f(this[i], i, this)); return r; };
if (!Array.prototype.filter) Array.prototype.filter = function (f) { var r = [], i; for (i = 0; i < this.length; i++) if (f(this[i], i, this)) r.push(this[i]); return r; };
if (!Array.prototype.forEach) Array.prototype.forEach = function (f) { for (var i = 0; i < this.length; i++) f(this[i], i, this); };
if (!Date.now) Date.now = function () { return new Date().getTime(); };

function makeEl(tag) {
  var o = {
    tagName: tag, attributes: {}, style: {},
    classList: {
      _s: {}, add: function (c) { this._s[c] = 1; }, remove: function (c) { delete this._s[c]; },
      toggle: function (c, f) { if (f === undefined) { if (this._s[c]) delete this._s[c]; else this._s[c] = 1; } else { if (f) this._s[c] = 1; else delete this._s[c]; } },
      contains: function (c) { return !!this._s[c]; }
    },
    textContent: '', innerHTML: '', value: '', title: '', parentNode: null,
    setAttribute: function (k, v) { this.attributes[k] = v; }, getAttribute: function (k) { return this.attributes[k]; },
    appendChild: function (c) { c.parentNode = this; }, insertBefore: function (c, ref) { c.parentNode = this; }, removeChild: function (c) { },
    addEventListener: function () { }, focus: function () { }, files: null, checked: false, click: function () { }
  };
  if (tag === 'canvas') {
    o.width = 0; o.height = 0;
    o.getContext = function () { return makeNoopCtx(); };
    o.toBlob = function (cb) { cb(null); };
    o.toDataURL = function () { return 'data:image/png;base64,stub'; };
  }
  return o;
}
function makeNoopCtx() {
  return {
    scale: function () {}, clearRect: function () {}, beginPath: function () {}, moveTo: function () {},
    lineTo: function () {}, arc: function () {}, closePath: function () {}, fill: function () {},
    stroke: function () {}, save: function () {}, restore: function () {}, translate: function () {},
    rotate: function () {}, fillRect: function () {}, fillText: function () {}, strokeText: function () {},
    setLineDash: function () {}, measureText: function (s) { return { width: String(s).length * 12 }; }
  };
}
var URL = { createObjectURL: function () { return 'blob:stub'; }, revokeObjectURL: function () { } };
var Blob = function (parts, opts) { this.parts = parts || []; this.type = (opts && opts.type) || ''; };
var __reg = {};
var document = {
  // 与真浏览器一致：'#id' 带井号会查不到（getElementById 只接受裸 id），抓到 $('#x') 这类误用
  getElementById: function (id) { if (id.charAt(0) === '#') return null; if (!__reg[id]) __reg[id] = makeEl('div'); return __reg[id]; },
  createElement: function (t) { return makeEl(t); }, addEventListener: function () { },
  querySelectorAll: function () { return []; }, head: makeEl('head'), body: makeEl('body'), hidden: false, __reg: __reg
};
var window = { addEventListener: function () { } };
var location = { protocol: 'http:' };
var navigator = { serviceWorker: { register: function () { } } };
var __ls = {};
var localStorage = {
  getItem: function (k) { return (k in __ls) ? __ls[k] : null; },
  setItem: function (k, v) { __ls[k] = String(v); },
  removeItem: function (k) { delete __ls[k]; }
};
var alert = function () { }, confirm = function () { return false; };
var setInterval = function () { return 0; }, setTimeout = function () { };
