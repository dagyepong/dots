.pragma library

var N = 48
var TRACES = 4
var FREQ = [1.1, 1.9, 3.1, 4.7, 6.8, 9.3]
var SPEED = [0.9, 1.3, 1.7, 2.3, 2.9, 3.7]
var SKEW = [0.0, 1.7, 3.1, 0.6, 2.4, 4.4]
var WEIGHT = [0.55, 0.42, 0.36, 0.30, 0.25, 0.2]
var FIRST = [0, 4, 9, 16, 25, 36]
var LAST = [3, 8, 15, 24, 35, 49]
var LAG = 0.16
var KICK = [1.4, 0.9, 0.5, 0.3, 0.2, 0.15]

function clip(x) {
    var a = Math.abs(x) / 1.05
    return x / Math.pow(1 + a * a * a * a, 0.25)
}

function fill(out, levels, travel, kick, traces) {
    var amp = []
    for (var k = 0; k < FREQ.length; k++) {
        var sum = 0
        for (var i = FIRST[k]; i <= LAST[k]; i++)
            sum += levels[i] || 0
        amp.push(WEIGHT[k] * (0.05 + Math.pow(sum / (LAST[k] - FIRST[k] + 1), 0.7)) * (1 + KICK[k] * kick))
    }
    var lag = LAG * (1 + 2.5 * kick)
    for (var tr = 0; tr < TRACES; tr++) {
        var tt = travel - tr * lag
        for (var n = 0; n < N; n++) {
            if (tr >= traces) { out[tr * N + n] = 0; continue }
            var u = n / (N - 1)
            var y = 0
            for (var j = 0; j < FREQ.length; j++)
                y += amp[j] * Math.sin(2 * Math.PI * FREQ[j] * u - SPEED[j] * tt + SKEW[j])
            var env = 0.3 + 0.7 * Math.pow(Math.sin(Math.PI * u), 0.7)
            out[tr * N + n] = clip(y * env * 2.3)
        }
    }
}
