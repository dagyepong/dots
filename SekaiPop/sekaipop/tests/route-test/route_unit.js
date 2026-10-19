// node tests/route-test/route_unit.js   (run from the sekaipop folder)
const fs = require("fs")
const src = fs.readFileSync(__dirname + "/../../modules/sekai/quickPanel/PhoneRoute.js", "utf8").replace(".pragma library", "")
const R = new Function(src + "; return { open, top, floor, go, back, home, byNumber, startsSearch, isScreen }")()

let fails = 0
function eq(a, b, msg) {
    const x = JSON.stringify(a), y = JSON.stringify(b)
    if (x !== y) { fails++; console.log("FAIL " + msg + "\n   got  " + x + "\n   want " + y) }
}

// Opening
eq(R.open("quick"), { stack: ["quick"] }, "open quick")
eq(R.open("apps"), { stack: ["apps"] }, "open apps")
eq(R.open("nonsense"), { stack: ["quick"] }, "unknown entry -> quick")
eq(R.open(undefined), { stack: ["quick"] }, "undefined entry -> quick")

// Quick -> Apps -> Back -> Quick -> Back closes
let s = R.open("quick")
s = R.go(s, "apps")
eq(R.top(s), "apps", "top after go apps")
let b = R.back(s)
eq(b.closed, false, "back from apps does not close")
eq(R.top(b.state), "quick", "back from apps lands on quick")
b = R.back(b.state)
eq(b.closed, true, "back at the floor closes")

// Keyboard launch: floor is Apps, Escape closes, never goes to Quick
s = R.open("apps")
b = R.back(s)
eq(b.closed, true, "apps floor: back closes")
eq(R.floor(s), "apps", "floor is apps")

// Deep path then Back retraces it
s = R.open("quick")
s = R.go(s, "apps")
s = R.go(s, "wallpapers")
eq(s.stack, ["quick", "apps", "wallpapers"], "path q>a>w")
b = R.back(s); eq(R.top(b.state), "apps", "back w -> a")
b = R.back(b.state); eq(R.top(b.state), "quick", "back a -> q")

// Going to something already in the stack pops down to it (no duplicates)
s = R.go(R.go(R.open("quick"), "apps"), "settings")
s = R.go(s, "apps")
eq(s.stack, ["quick", "apps"], "go apps from settings pops back to apps")
s = R.go(s, "apps")
eq(s.stack, ["quick", "apps"], "go to the screen already showing is a no-op")

// Home clears to Quick and Back then closes
s = R.home(R.go(R.go(R.open("apps"), "wallpapers"), "settings"))
eq(s.stack, ["quick"], "home -> [quick]")
eq(R.back(s).closed, true, "after home, back closes")

// Bad names are ignored
s = R.open("quick")
eq(R.go(s, "bogus"), s, "go bogus ignored")
eq(R.go(s, ""), s, "go empty ignored")

// Numbers
eq([1, 2, 3, 4].map(R.byNumber), ["quick", "apps", "wallpapers", "settings"], "ctrl+N order")
eq(R.byNumber(0), "", "0 -> none")
eq(R.byNumber(5), "", "5 -> none")

// Typing
eq(R.startsSearch("f", false, false, false), true, "letter starts search")
eq(R.startsSearch("7", false, false, false), true, "digit starts search")
eq(R.startsSearch(" ", false, false, false), false, "space does not")
eq(R.startsSearch("", false, false, false), false, "empty does not")
eq(R.startsSearch("f", true, false, false), false, "ctrl+f does not")
eq(R.startsSearch("f", false, true, false), false, "alt+f does not")
eq(R.startsSearch("f", false, false, true), false, "super+f does not")
eq(R.startsSearch("ab", false, false, false), false, "two chars does not")
eq(R.startsSearch("\u007f", false, false, false), false, "DEL does not")
eq(R.startsSearch("\r", false, false, false), false, "enter does not")

// States are not changed in place
s = R.open("quick"); const before = JSON.stringify(s)
R.go(s, "apps"); R.back(s); R.home(s)
eq(JSON.stringify(s), before, "input state untouched")

console.log(fails === 0 ? "ALL PASS" : fails + " FAILED")
process.exit(fails === 0 ? 0 : 1)
