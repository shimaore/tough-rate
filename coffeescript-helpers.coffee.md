coffeescript_helpers = """
var __slice = [].slice;
var __hasProp = {}.hasOwnProperty;
var __bind = function(fn, me){
return function(){ return fn.apply(me, arguments); };
};
var __extends = function(child, parent) {
for (var key in parent) {
if (__hasProp.call(parent, key)) child[key] = parent[key];
}
function ctor() { this.constructor = child; }
ctor.prototype = parent.prototype;
child.prototype = new ctor();
child.__super__ = parent.prototype;
return child;
};
var __indexOf = [].indexOf || function(item) {
for (var i = 0, l = this.length; i < l; i++) {
if (i in this && this[i] === item) return i;
} return -1; };
var __modulo = function(a, b) { return (+a % (b = +b) + b) % b; };
""".replace /\n/g, ''
