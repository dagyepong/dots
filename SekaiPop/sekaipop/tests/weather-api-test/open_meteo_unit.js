// node tests/weather-api-test/open_meteo_unit.js   (run from the sekaipop folder)
//
// The weather source (services/WeatherSource.qml) is built on Open-Meteo; every bit
// of parsing is in modules/common/functions/OpenMeteo.js, which this runs on its
// own. Quickshell and the network can't be used here, so the sample answers below
// were written by hand from Open-Meteo's documented response shape (they are NOT
// recordings of a live call) -- a check of OUR logic, not of the service.
//   1. what is typed: auto / city / "city, qualifier" / lat,lon
//   2. the search answer: which place is picked, and its label
//   3. WMO codes -> text and icon (day and night)
//   4. a forecast answer -> every string the pill, popup and card read, in C and in F
//   5. awkward answers: missing fields, no "now" in the hourly list, errors
//   6. the QML is wired to it (no wttr.in left, strings, process chain)
const fs = require("fs"), assert = require("assert")
const locate = require("../lib/locate")
const read = f => fs.readFileSync(locate(f), "utf8")
const src = read("modules/common/functions/OpenMeteo.js").replace(".pragma library", "")
const OM = {}
new Function("OM", src + ";Object.assign(OM,{parseQuery,geocodeUrl,forecastUrl,norm,pickPlace,placeLabel,coordLabel,placeFromIp,describe,iconFor,compass,clock12,buildReading,dayLabelEnglish,GEOCODE_URL,FORECAST_URL,IP_URL});")(OM)
let n = 0
const ok = (c, m) => { assert(c, m); n++ }
const eq = (a, b, m) => { assert.deepStrictEqual(a, b, m); n++ }

// ---- 1. what is typed ----
eq(OM.parseQuery(""), { kind: "auto" })
eq(OM.parseQuery("   "), { kind: "auto" })
eq(OM.parseQuery(undefined), { kind: "auto" })
eq(OM.parseQuery("Majayjay"), { kind: "name", name: "Majayjay", qualifier: "" })
eq(OM.parseQuery("  Los   Angeles "), { kind: "name", name: "Los   Angeles", qualifier: "" })
eq(OM.parseQuery("Springfield, Illinois"), { kind: "name", name: "Springfield", qualifier: "Illinois" })
eq(OM.parseQuery("Paris,France"), { kind: "name", name: "Paris", qualifier: "France" })
eq(OM.parseQuery("Paris, Texas, USA"), { kind: "name", name: "Paris", qualifier: "Texas USA" })
eq(OM.parseQuery("~Lisbon"), { kind: "name", name: "Lisbon", qualifier: "" })
eq(OM.parseQuery("14.15, 121.47"), { kind: "coords", lat: 14.15, lon: 121.47 })
eq(OM.parseQuery("-33.86,151.21"), { kind: "coords", lat: -33.86, lon: 151.21 })
eq(OM.parseQuery("95, 10"), { kind: "name", name: "95", qualifier: "10" }, "out-of-range pair is not coordinates")
ok(OM.geocodeUrl("São Paulo").indexOf("name=S%C3%A3o%20Paulo") > 0, "name is URL-encoded")
ok(OM.geocodeUrl("a&b=c").indexOf("name=a%26b%3Dc") > 0, "no parameter injection through the name")

// ---- 2. the search answer ----
const springfield = [
    { name: "Springfield", country: "United States", country_code: "US", admin1: "Illinois", latitude: 39.8, longitude: -89.64 },
    { name: "Springfield", country: "United States", country_code: "US", admin1: "Missouri", latitude: 37.2, longitude: -93.3 },
    { name: "Springfield", country: "United Kingdom", country_code: "GB", admin1: "England", latitude: 51.7, longitude: 0.48 }
]
eq(OM.pickPlace(springfield, "").admin1, "Illinois", "no qualifier: the first (best-known)")
eq(OM.pickPlace(springfield, "Missouri").admin1, "Missouri")
eq(OM.pickPlace(springfield, "missouri").admin1, "Missouri", "case does not matter")
eq(OM.pickPlace(springfield, "GB").country_code, "GB", "country code")
eq(OM.pickPlace(springfield, "united kingdom").country_code, "GB", "country name")
eq(OM.pickPlace(springfield, "Atlantis").admin1, "Illinois", "unknown qualifier: first answer stays")
eq(OM.pickPlace([{ name: "Zürich", country: "Schweiz", admin1: "Zürich" }], "zurich").name, "Zürich")
eq(OM.pickPlace([{ name: "A", country: "Brasil", admin1: "Goiás" }, { name: "B", country: "Brasil", admin1: "Brasília" }], "brasilia").name, "B", "accents ignored in the region")
eq(OM.pickPlace([], ""), null)
eq(OM.pickPlace(undefined, "x"), null, "no results key (a city that is not found)")
eq(OM.placeLabel({ name: "Majayjay", country: "Philippines", admin1: "Calabarzon" }), "Majayjay, Philippines")
eq(OM.placeLabel({ name: "Nowhere" }), "Nowhere")
eq(OM.coordLabel(14.1534, 121.4712), "14.15, 121.47")
eq(OM.placeFromIp({ success: true, city: "Manila", country: "Philippines", latitude: 14.6, longitude: 120.98 }),
   { lat: 14.6, lon: 120.98, label: "Manila, Philippines" })
eq(OM.placeFromIp({ success: false, message: "Invalid IP address" }), null)
eq(OM.placeFromIp({ success: true, latitude: null, longitude: null }), null)
eq(OM.placeFromIp(null), null)

// ---- 3. WMO codes ----
eq(OM.describe(0), "Clear sky"); eq(OM.describe(95), "Thunderstorm"); eq(OM.describe(1234), "Unknown"); eq(OM.describe(null), "Unknown")
const icons = { 0: ["sunny", "clear_night"], 1: ["sunny", "clear_night"], 2: ["partly_cloudy_day", "partly_cloudy_night"],
    3: ["cloud", "cloud"], 45: ["foggy", "foggy"], 48: ["foggy", "foggy"], 51: ["rainy", "rainy"], 57: ["rainy", "rainy"],
    61: ["rainy", "rainy"], 67: ["rainy", "rainy"], 71: ["weather_snowy", "weather_snowy"], 77: ["weather_snowy", "weather_snowy"],
    80: ["rainy", "rainy"], 82: ["rainy", "rainy"], 85: ["weather_snowy", "weather_snowy"], 86: ["weather_snowy", "weather_snowy"],
    95: ["thunderstorm", "thunderstorm"], 96: ["thunderstorm", "thunderstorm"], 99: ["thunderstorm", "thunderstorm"] }
for (const c in icons) { eq(OM.iconFor(+c, false), icons[c][0], "day " + c); eq(OM.iconFor(+c, true), icons[c][1], "night " + c) }
// only the icons WeatherGlyph can draw
const glyph = read("modules/common/widgets/WeatherGlyph.qml")
for (const name of new Set(Object.values(icons).flat()))
    ok(glyph.indexOf('"' + name + '"') >= 0, "WeatherGlyph does not draw " + name)
// every code Open-Meteo documents has a text
for (const c of [0,1,2,3,45,48,51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99])
    ok(OM.describe(c) !== "Unknown", "no text for " + c)
eq(OM.compass(0), "N"); eq(OM.compass(90), "E"); eq(OM.compass(225), "SW"); eq(OM.compass(359), "N"); eq(OM.compass(-90), "W"); eq(OM.compass(null), ""); eq(OM.compass("x"), "")
eq(OM.clock12("2026-10-15T05:48"), "05:48 AM"); eq(OM.clock12("2026-10-15T17:30"), "05:30 PM")
eq(OM.clock12("2026-10-15T00:05"), "12:05 AM"); eq(OM.clock12("2026-10-15T12:00"), "12:00 PM"); eq(OM.clock12(null), "")

// ---- 4. a forecast answer ----
// 72 hourly slots from 2026-10-15 00:00 (place-local time), "now" is 14:15.
const times = [], H = {}
for (const k of ["temperature_2m", "apparent_temperature", "precipitation_probability", "weather_code", "is_day", "visibility", "uv_index"]) H[k] = []
for (let i = 0; i < 72; i++) {
    const day = 15 + Math.floor(i / 24), hr = i % 24
    times.push("2026-10-" + day + "T" + ("0" + hr).slice(-2) + ":00")
    H.temperature_2m.push(20 + hr / 2)          // 20.0 .. 31.5
    H.apparent_temperature.push(22 + hr / 2)
    H.precipitation_probability.push(i % 5 * 10)
    H.weather_code.push(hr >= 12 && hr < 15 ? 61 : 2)
    H.is_day.push(hr >= 6 && hr < 18 ? 1 : 0)
    H.visibility.push(24140)
    H.uv_index.push(hr === 14 ? 8.4 : 0)
}
const data = {
    current: { time: "2026-10-15T14:15", temperature_2m: 27.0, relative_humidity_2m: 71.4, apparent_temperature: 31.6, is_day: 1,
               precipitation: 0.24, weather_code: 61, pressure_msl: 1008.3, wind_speed_10m: 12.4, wind_direction_10m: 225 },
    hourly: Object.assign({ time: times }, H),
    daily: { time: ["2026-10-15", "2026-10-16", "2026-10-17"], weather_code: [61, 3, 95],
             temperature_2m_max: [31.5, 30.2, 28.0], temperature_2m_min: [20.0, 19.5, 21.4],
             precipitation_probability_max: [80, 20, 90], uv_index_max: [9.1, 8, 7],
             sunrise: ["2026-10-15T05:48", "2026-10-16T05:48", "2026-10-17T05:47"],
             sunset: ["2026-10-15T17:32", "2026-10-16T17:31", "2026-10-17T17:30"] }
}
const c = OM.buildReading(data, { fahrenheit: false })
eq(c.temperatureText, "27°C"); eq(c.conditionText, "Light rain"); eq(c.iconName, "rainy")
eq(c.feelsLikeText, "32°C"); eq(c.humidityText, "71%"); eq(c.windText, "12 km/h SW"); eq(c.pressureText, "1008 hPa")
eq(c.visibilityText, "24 km"); eq(c.uvText, "8", "uv of the current hour"); eq(c.precipText, "0.2 mm")
eq(c.sunriseText, "05:48 AM"); eq(c.sunsetText, "05:32 PM")
eq(c.forecast.length, 3)
eq(c.forecast[0], { label: "Today", date: 15, iconName: "rainy", condition: "Light rain", high: "32°", low: "20°", rain: 80 })
eq(c.forecast[1].label, "Fri", "2026-10-16 is a Friday"); eq(c.forecast[2].label, "Sat"); eq(c.forecast[2].iconName, "thunderstorm")
eq(c.hourly.length, 8, "eight readings")
eq(c.hourly.map(h => h.label), ["14:00", "17:00", "20:00", "23:00", "02:00", "05:00", "08:00", "11:00"], "three hours apart, from now, across midnight")
eq(c.hourly[0], { label: "14:00", iconName: "rainy", condition: "Light rain", temp: "27°", feels: "29°", rain: 40 })
eq(c.hourly[2].iconName, "partly_cloudy_night", "20:00 is night (is_day 0)")
const fh = OM.buildReading(data, { fahrenheit: true })
eq(fh.temperatureText, "81°F"); eq(fh.feelsLikeText, "89°F"); eq(fh.windText, "8 mph SW"); eq(fh.visibilityText, "15 mi"); eq(fh.precipText, "0.01 in")
eq(fh.forecast[0].high, "89°"); eq(fh.forecast[0].low, "68°"); eq(fh.hourly[0].temp, "81°")
eq(fh.conditionText, c.conditionText, "unit flip changes numbers only")
const custom = OM.buildReading(data, { dayLabel: (iso, i) => i + ":" + iso })
eq(custom.forecast[1].label, "1:2026-10-16", "the shell's own day-label function is used")
// the formats the popup / card parse (WeatherMath.js)
const WM = {}
new Function("WM", read("modules/common/functions/WeatherMath.js").replace(".pragma library", "") + ";Object.assign(WM,{splitTemp,firstNumber,windParts,windArrow});")(WM)
eq(WM.splitTemp(c.temperatureText), { num: "27", unit: "°C" }); eq(WM.splitTemp(fh.temperatureText), { num: "81", unit: "°F" })
eq(WM.windParts(c.windText), { speed: "12 km/h", dir: "SW" }); eq(WM.windArrow(c.windText), 45, "SW wind blows towards NE (45 deg)")
eq(WM.firstNumber(c.humidityText), 71); eq(WM.firstNumber(c.uvText), 8)
eq(WM.splitTemp(OM.buildReading(Object.assign({}, data, { current: Object.assign({}, data.current, { temperature_2m: -3.4 }) }), {}).temperatureText), { num: "-3", unit: "°C" })

// ---- 5. awkward answers ----
assert.throws(() => OM.buildReading({}, {}), /no current/); n++
assert.throws(() => OM.buildReading({ error: true, reason: "Latitude must be in range of -90 to 90" }, {}), /no current/); n++
assert.throws(() => OM.buildReading(null, {}), /no current/); n++
const thin = OM.buildReading({ current: { time: "2026-10-15T09:00", temperature_2m: 18.6, weather_code: 3 } }, {})
eq(thin.temperatureText, "19°C"); eq(thin.humidityText, ""); eq(thin.windText, ""); eq(thin.pressureText, ""); eq(thin.visibilityText, "")
eq(thin.uvText, ""); eq(thin.forecast, []); eq(thin.hourly, []); eq(thin.sunriseText, ""); eq(thin.iconName, "cloud"); eq(thin.precipText, "0.0 mm")
const nonow = OM.buildReading(Object.assign({}, data, { current: Object.assign({}, data.current, { time: "2030-01-01T00:00" }) }), {})
eq(nonow.hourly[0].label, "00:00", "no matching hour: the list starts at its first slot rather than breaking")
const shortList = OM.buildReading(Object.assign({}, data, { hourly: Object.assign({}, data.hourly, { time: times.slice(0, 20) }) }), {})
eq(shortList.hourly.length, 2, "fewer readings left than eight: only those")
const night = OM.buildReading({ current: { time: "2026-10-15T23:00", temperature_2m: 20, weather_code: 0, is_day: 0 } }, {})
eq(night.iconName, "clear_night")

// ---- 6. the QML ----
const ws = read("services/WeatherSource.qml")
const code = s => s.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'])\/\/.*$/gm, "$1")
const wc = code(ws)
ok(!/wttr/.test(wc), "WeatherSource still talks to wttr.in")
ok(/import "\.\.\/modules\/common\/functions\/OpenMeteo\.js" as OM/.test(wc), "imports OpenMeteo.js")
for (const id of ["geocode", "ipLookup", "fetch"]) ok(new RegExp("Process \\{\\s*id: " + id + "\\b").test(wc), "Process " + id)
ok(/command: \["curl", "-s", "-m", "10", root\.geocodeUrl\]/.test(wc), "geocode runs curl with the URL as one argument")
ok(/command: \["curl", "-s", "-m", "10", root\.forecastUrl\]/.test(wc), "forecast runs curl")
ok(/SettingsService\.get\("weather\.location"\)/.test(wc), "reads the Location setting")
ok(/onLocationChanged:/.test(wc) && /root\.place = null/.test(wc), "a new Location forgets the old place")
// every property the consumers read is still there
for (const p of ["temperatureText", "conditionText", "iconName", "feelsLikeText", "humidityText", "windText", "pressureText", "visibilityText", "uvText",
                 "precipText", "areaText", "sunriseText", "sunsetText", "forecast", "hourly", "updatedText", "loading", "failed", "problemText", "lastFetchMs", "polling"])
    ok(new RegExp("(property|readonly property) \\w+ " + p + "\\b").test(wc), "WeatherSource lost " + p)
for (const fn of ["refresh", "refreshIfStale"]) ok(new RegExp("function " + fn + "\\(").test(wc), "WeatherSource lost " + fn + "()")
const used = new Set()
for (const f of ["modules/sekai/bar/WeatherPopup.qml", "modules/sekai/desktopWidgets/WeatherCardWidget.qml", "modules/sekai/bar/Status_Bar.qml", "modules/sekai/bar/WeatherIndicator.qml"]) {
    const t = code(read(f))
    for (const m of t.matchAll(/\b(?:source|wx|weatherSource)\.([a-zA-Z]+)/g)) used.add(m[1])
}
for (const p of used) if (/Text$|^(forecast|hourly|iconName|loading|failed|polling|refresh|refreshIfStale|lastFetchMs|problemText)$/.test(p))
    ok(new RegExp("\\b" + p + "\\b").test(wc), "a consumer reads " + p + " which WeatherSource lacks")
ok(!/wttr/.test(code(read("modules/sekai/bar/WeatherPopup.qml"))), "popup says wttr.in")
ok(!/wttr/.test(code(read("modules/sekai/desktopWidgets/WeatherCardWidget.qml"))), "card says wttr.in")
ok(/root\.source\.problemText/.test(read("modules/sekai/bar/WeatherPopup.qml")), "popup shows problemText")
ok((read("modules/sekai/desktopWidgets/WeatherCardWidget.qml").match(/wx\.problemText/g) || []).length === 2, "card shows problemText (both faces)")
ok(/Type your city/.test(read("modules/sekai/settings/SettingsPageGeneral.qml")), "Settings asks for a city")
// the location setting is still a preset-exempt, plain string
ok(/"weather\.location": ""/.test(read("services/SettingsService.qml")), "default stays empty = automatic")

console.log("ok  " + n + " checks")
