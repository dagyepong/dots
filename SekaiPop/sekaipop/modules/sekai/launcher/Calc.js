.pragma library

// The calculator's brain (CalculatorCard.qml) -- pure JavaScript, no QML, so
// it can be tried on its own. It is a small hand-written parser rather than
// eval(): only numbers, operators and the functions below are understood, so
// nothing you type can run as code.
//
//   + - * / ^        ^ is a power, right-to-left: 2^3^2 = 2^9
//   % (after a number)   percent: 50% = 0.5, so 200*10% = 20
//   ( )              brackets; a missing ) at the end is filled in
//   2(3+4), 2pi      writing two things next to each other multiplies them
//   pi e tau         constants
//   sqrt cbrt abs sin cos tan asin acos atan ln log log2 exp floor ceil round
//                    trig works in radians
//   x mod y          the remainder (mod)
//
// The pretty symbols the keypad shows (x, /, -, square root) are accepted
// too, so pasting "12 x 3" from a web page works.

var FUNCTIONS = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs,
    sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asin: Math.asin, acos: Math.acos, atan: Math.atan,
    ln: Math.log, log: Math.log10, log2: Math.log2, exp: Math.exp,
    floor: Math.floor, ceil: Math.ceil, round: Math.round
};

var CONSTANTS = { pi: Math.PI, e: Math.E, tau: 2 * Math.PI };

function normalise(s) {
    return String(s)
        .replace(/[\u00d7\u2715\u2716]/g, "*")      // x  (multiplication signs)
        .replace(/[\u00f7\u2215]/g, "/")            // /  (division signs)
        .replace(/[\u2212\u2013\u2014]/g, "-")      // minus, en dash, em dash
        .replace(/\u221a/g, "sqrt")                 // square root sign
        .replace(/\u03c0/g, "pi")
        .replace(/\u03c4/g, "tau")
        .replace(/[\s\u00a0\u2009]+/g, " ")
        .trim()
        .toLowerCase()
        .replace(/(\d|\))\s*x\s*(?=[\d(.])/g, "$1*");     // 12 x 3
}

// ===== tokenizer =====
function tokenize(src) {
    var tokens = [];
    var i = 0;
    while (i < src.length) {
        var ch = src.charAt(i);
        var m;
        if (ch === " ") {
            i++;
        } else if (/[0-9.]/.test(ch)) {
            // 12, 12.5, .5, 1e3, 1.5e-3 (an e only counts as an exponent when
            // digits follow it, so "2e" is 2 x e)
            m = /^(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/.exec(src.slice(i));
            if (!m) throw "Bad number";
            tokens.push({ t: "num", v: parseFloat(m[0]) });
            i += m[0].length;
        } else if (/[a-z]/.test(ch)) {
            m = /^[a-z]+/.exec(src.slice(i));
            var word = m[0];
            var withDigit = word + src.charAt(i + word.length);
            if (FUNCTIONS.hasOwnProperty(withDigit))     // log2
                word = withDigit;
            tokens.push({ t: "id", v: word });
            i += word.length;
        } else if ("+-*/^%(),".indexOf(ch) >= 0) {
            tokens.push({ t: ch });
            i++;
        } else {
            throw "Unexpected \"" + ch + "\"";
        }
    }
    return tokens;
}

// ===== parser =====
function parse(tokens) {
    var pos = 0;

    function peek() { return pos < tokens.length ? tokens[pos] : null; }
    function next() { return tokens[pos++]; }
    function is(t) { var p = peek(); return p !== null && p.t === t; }
    function startsPrimary() {
        var p = peek();
        return p !== null && (p.t === "num" || p.t === "(" || (p.t === "id" && p.v !== "mod"));
    }

    function expr() {
        var v = term();
        while (is("+") || is("-")) {
            var op = next().t;
            var from = pos;
            var r = term();
            // "200+10%" is 200 plus ten percent of 200 (220), not 200.1
            if (pos - from === 2 && tokens[from].t === "num" && tokens[from + 1].t === "%")
                r = v * r;
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }

    function term() {
        var v = unary();
        for (;;) {
            if (is("*")) { next(); v = v * unary(); }
            else if (is("/")) { next(); v = v / unary(); }
            else if (peek() !== null && peek().t === "id" && peek().v === "mod") { next(); v = v % unary(); }
            else if (startsPrimary()) v = v * unary();   // 2(3), 2pi
            else return v;
        }
    }

    function unary() {
        if (is("-")) { next(); return -unary(); }
        if (is("+")) { next(); return unary(); }
        return power();
    }

    function power() {
        var base = postfix();
        if (is("^")) { next(); return Math.pow(base, unary()); }
        return base;
    }

    function postfix() {
        var v = primary();
        while (is("%")) { next(); v = v / 100; }
        return v;
    }

    function primary() {
        var p = next();
        if (!p) throw "Incomplete";
        if (p.t === "num") return p.v;
        if (p.t === "(") {
            var v = expr();
            if (!is(")")) throw "Missing )";
            next();
            return v;
        }
        if (p.t === "id") {
            if (CONSTANTS.hasOwnProperty(p.v)) return CONSTANTS[p.v];
            if (FUNCTIONS.hasOwnProperty(p.v)) {
                var arg = is("(") ? primary() : power();   // sqrt(9) or sqrt9
                return FUNCTIONS[p.v](arg);
            }
            throw "Unknown \"" + p.v + "\"";
        }
        throw "Unexpected \"" + p.t + "\"";
    }

    var result = expr();
    if (pos < tokens.length) throw "Unexpected \"" + tokens[pos].t + "\"";
    return result;
}

// Make a half-typed expression evaluable: drop trailing operators, close
// any brackets still open. "12+(3*" -> "12+(3)".
function complete(src) {
    var s = src.replace(/[+\-*\/^]+$/, "");
    var open = 0;
    for (var i = 0; i < s.length; i++) {
        if (s.charAt(i) === "(") open++;
        else if (s.charAt(i) === ")") open--;
    }
    // "sqrt(" with nothing inside ends up "sqrt()" -- strip that back too
    while (open > 0) { s += ")"; open--; }
    return s;
}

// Result: { ok: true, value: 42, text: "42" } or { ok: false, error: "..." }.
// Empty input is { ok: false, error: "" } (nothing to show, not an error).
function evaluate(input) {
    var src = normalise(input);
    if (src === "") return { ok: false, error: "" };
    var value;
    try {
        value = parse(tokenize(src));
    } catch (first) {
        try {
            value = parse(tokenize(complete(src)));
        } catch (e) {
            return { ok: false, error: String(typeof first === "string" ? first : e) };
        }
    }
    if (typeof value !== "number" || isNaN(value)) return { ok: false, error: "Not a number" };
    if (!isFinite(value)) return { ok: false, error: "Can't divide by zero" };
    return { ok: true, value: value, text: format(value) };
}

// 12 significant digits, so 0.1+0.2 reads 0.3 rather than 0.30000000000000004.
function format(v) {
    if (v === 0) return "0";
    var s = parseFloat(v.toPrecision(12)).toString();
    if (s.indexOf("e") >= 0) return s.replace("e+", "e");
    return s;
}

// 1234567.891 -> "1,234,567.891" (for showing, never for copying)
function group(text) {
    if (text.indexOf("e") >= 0) return text;
    var neg = text.charAt(0) === "-";
    var body = neg ? text.slice(1) : text;
    var dot = body.indexOf(".");
    var whole = dot >= 0 ? body.slice(0, dot) : body;
    var frac = dot >= 0 ? body.slice(dot) : "";
    whole = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return (neg ? "-" : "") + whole + frac;
}

// Show the expression the way a calculator would.
function pretty(src) {
    return String(src)
        .replace(/\*/g, "\u00d7")
        .replace(/\//g, "\u00f7")
        .replace(/(^|[^0-9.)e%])-/g, "$1\u2212")     // a minus after an operator
        .replace(/([0-9.)%])-/g, "$1\u2212")
        .replace(/sqrt\(/g, "\u221a(")
        .replace(/\bpi\b/g, "\u03c0");
}

// Is this whole search-box text plainly arithmetic ("2+2", "(3+4)*5")? Used
// so that typing a sum pops the calculator without typing "calc" first. It has
// to end in a digit, ), or %, so half-typed things like "7-" (on the way to
// "7-zip") do not flicker the calculator up.
function looksLikeMath(q) {
    var s = String(q).trim();
    if (s.length < 3) return false;
    if (!/^[0-9+\-*\/^%().\s\u00d7\u00f7\u2212]+$/.test(s)) return false;
    if (!/[0-9]$|[)%]$/.test(s)) return false;
    if (!/[0-9)%]\s*[+\-*\/^\u00d7\u00f7\u2212]/.test(s)) return false;   // an operator that is not just a leading sign
    return true;
}
