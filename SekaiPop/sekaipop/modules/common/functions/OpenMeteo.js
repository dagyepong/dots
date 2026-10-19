.pragma library

// Pure helpers for services/WeatherSource.qml -- no QML, so they can be run on
// their own (tests/weather-api-test/open_meteo_unit.js).
//
// The weather now comes from Open-Meteo (open-meteo.com): free, no API key, and
// it has a city-name search of its own, so the person only types a city:
//
//   1. geocoding-api.open-meteo.com/v1/search?name=Majayjay   -> latitude / longitude
//   2. api.open-meteo.com/v1/forecast?latitude=..&longitude=.. -> the weather
//
// With nothing typed, ipwho.is guesses the city from the public IP (the way
// wttr.in used to). Everything below turns what those three answer into the
// strings the bar pill, the popup and the desktop card already show.

var GEOCODE_URL = "https://geocoding-api.open-meteo.com/v1/search";
var FORECAST_URL = "https://api.open-meteo.com/v1/forecast";
var IP_URL = "https://ipwho.is/";

var POINTS = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
              "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];

function pad(n) {
    return ("0" + n).slice(-2);
}

// What was typed in Settings -> General -> Weather -> Location:
//   ""                      -> { kind: "auto" }
//   "Majayjay"              -> { kind: "name", name: "Majayjay", qualifier: "" }
//   "Springfield, Illinois" -> { kind: "name", name: "Springfield", qualifier: "Illinois" }
//   "14.15, 121.47"         -> { kind: "coords", lat: 14.15, lon: 121.47 }
function parseQuery(text) {
    var s = String(text === undefined || text === null ? "" : text).trim();
    // wttr.in's "~Place" marker means nothing here.
    if (s.charAt(0) === "~")
        s = s.slice(1).trim();
    if (s === "")
        return { kind: "auto" };
    var m = /^(-?\d{1,2}(?:\.\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:\.\d+)?)$/.exec(s);
    if (m) {
        var lat = parseFloat(m[1]), lon = parseFloat(m[2]);
        if (Math.abs(lat) <= 90 && Math.abs(lon) <= 180)
            return { kind: "coords", lat: lat, lon: lon };
    }
    var cut = s.indexOf(",");
    if (cut < 0)
        return { kind: "name", name: s, qualifier: "" };
    var name = s.slice(0, cut).trim();
    var qualifier = s.slice(cut + 1).replace(/,/g, " ").replace(/\s+/g, " ").trim();
    if (name === "")
        return { kind: "name", name: qualifier, qualifier: "" };
    return { kind: "name", name: name, qualifier: qualifier };
}

function geocodeUrl(name) {
    return GEOCODE_URL + "?name=" + encodeURIComponent(name) + "&count=10&language=en&format=json";
}

function forecastUrl(lat, lon) {
    return FORECAST_URL + "?latitude=" + Number(lat).toFixed(4) + "&longitude=" + Number(lon).toFixed(4)
        + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,"
        + "weather_code,pressure_msl,wind_speed_10m,wind_direction_10m"
        + "&hourly=temperature_2m,apparent_temperature,precipitation_probability,weather_code,is_day,"
        + "visibility,uv_index"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,"
        + "uv_index_max,sunrise,sunset"
        + "&timezone=auto&forecast_days=3&temperature_unit=celsius&wind_speed_unit=kmh";
}

// Lower case, no accents, so "Zürich" matches "zurich" and "Brasília" "brasilia".
function norm(s) {
    var t = String(s === undefined || s === null ? "" : s).toLowerCase();
    if (t.normalize)
        t = t.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    return t.replace(/\s+/g, " ").trim();
}

// Open-Meteo's search only takes a name, so "Springfield, Illinois" is searched
// as "Springfield" and the answers are filtered by what came after the comma
// (country, country code, region). The first answer is the best-known place of
// that name. No match for the qualifier: the first answer still stands, and its
// full name is on show, so a wrong guess is visible.
function pickPlace(results, qualifier) {
    if (!results || results.length === 0)
        return null;
    var q = norm(qualifier);
    if (q !== "") {
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            if (norm(r.country_code) === q || norm(r.country) === q)
                return r;
        }
        for (var j = 0; j < results.length; j++) {
            var p = results[j];
            var fields = [p.country, p.admin1, p.admin2, p.admin3];
            for (var k = 0; k < fields.length; k++) {
                var f = norm(fields[k]);
                if (f !== "" && (f === q || (q.length >= 3 && f.indexOf(q) >= 0)))
                    return p;
            }
        }
    }
    return results[0];
}

// "Majayjay, Philippines"
function placeLabel(place) {
    var name = place && place.name ? String(place.name) : "";
    var where = place && (place.country || place.admin1) ? String(place.country || place.admin1) : "";
    return name && where ? name + ", " + where : (name || where);
}

function coordLabel(lat, lon) {
    return Number(lat).toFixed(2) + ", " + Number(lon).toFixed(2);
}

// ipwho.is -> { lat, lon, label } or null
function placeFromIp(data) {
    if (!data || data.success === false)
        return null;
    var lat = Number(data.latitude), lon = Number(data.longitude);
    if (!isFinite(lat) || !isFinite(lon) || data.latitude === null || data.longitude === null)
        return null;
    return { lat: lat, lon: lon, label: placeLabel({ name: data.city, country: data.country }) };
}

var WMO_TEXT = {
    0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Rime fog",
    51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle", 56: "Freezing drizzle", 57: "Heavy freezing drizzle",
    61: "Light rain", 63: "Rain", 65: "Heavy rain", 66: "Freezing rain", 67: "Heavy freezing rain",
    71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
    80: "Light showers", 81: "Showers", 82: "Violent showers",
    85: "Snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm", 96: "Thunderstorm with hail", 99: "Thunderstorm with heavy hail"
};

function describe(code) {
    var t = WMO_TEXT[parseInt(code, 10)];
    return t === undefined ? "Unknown" : t;
}

// The Material Symbols name (what WeatherGlyph draws) for a WMO weather code.
function iconFor(code, night) {
    var c = parseInt(code, 10);
    if (c === 0 || c === 1)
        return night ? "clear_night" : "sunny";
    if (c === 2)
        return night ? "partly_cloudy_night" : "partly_cloudy_day";
    if (c === 3)
        return "cloud";
    if (c === 45 || c === 48)
        return "foggy";
    if (c >= 95 && c <= 99)
        return "thunderstorm";
    if ((c >= 71 && c <= 77) || c === 85 || c === 86)
        return "weather_snowy";
    if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82))
        return "rainy";
    return "cloud";
}

// Degrees (where the wind blows FROM) -> "NNE"; "" when unknown.
function compass(deg) {
    var d = Number(deg);
    if (deg === null || deg === undefined || !isFinite(d))
        return "";
    return POINTS[Math.round((((d % 360) + 360) % 360) / 22.5) % 16];
}

// "2026-10-15T05:48" -> "05:48 AM" (how the sunrise was written before).
function clock12(iso) {
    var m = /T(\d{2}):(\d{2})/.exec(String(iso || ""));
    if (!m)
        return "";
    var h = parseInt(m[1], 10);
    return pad(h % 12 === 0 ? 12 : h % 12) + ":" + m[2] + (h < 12 ? " AM" : " PM");
}

var DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

function dayLabelEnglish(iso, i) {
    if (i === 0)
        return "Today";
    var m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso || ""));
    if (!m)
        return "";
    return DAYS[new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], 12)).getUTCDay()];
}

function num(v) {
    return v === null || v === undefined || !isFinite(Number(v)) ? null : Number(v);
}

function at(arr, i) {
    return arr && i >= 0 && i < arr.length ? arr[i] : null;
}

// One Open-Meteo forecast answer -> every string and list the weather pill,
// popup and desktop card read. Open-Meteo is asked for metric units; the
// Fahrenheit / mph / inch figures are worked out here, so switching units
// redraws at once without asking again.
//   opts.fahrenheit  true for °F, mph, mi, in
//   opts.dayLabel    (iso, index) -> "Today" / "Thu" -- the shell passes one that
//                    follows the system language; the default is English
// Throws when the answer has no current reading.
function buildReading(data, opts) {
    var o = opts || {};
    var f = !!o.fahrenheit;
    var cur = data && data.current;
    if (!cur || num(cur.temperature_2m) === null)
        throw new Error("no current reading");

    var hourly = data.hourly || {};
    var times = hourly.time || [];
    var daily = data.daily || {};
    var dayLabel = o.dayLabel || dayLabelEnglish;

    var temp = function (c) {
        var v = num(c);
        if (v === null)
            return "--";
        return String(Math.round(f ? v * 9 / 5 + 32 : v));
    };
    var unit = f ? "°F" : "°C";

    // Where "now" sits in the hourly lists. Both clocks are the place's own
    // (timezone=auto), so this never depends on this machine's time zone.
    var key = String(cur.time || "").slice(0, 13);
    var idx = -1;
    for (var i = 0; i < times.length; i++) {
        if (String(times[i]).slice(0, 13) === key) {
            idx = i;
            break;
        }
    }
    var night = cur.is_day === 0;

    var windKmh = num(cur.wind_speed_10m);
    var windText = "";
    if (windKmh !== null) {
        windText = f ? Math.round(windKmh * 0.621371) + " mph" : Math.round(windKmh) + " km/h";
        var dir = compass(cur.wind_direction_10m);
        if (dir)
            windText += " " + dir;
    }

    var vis = num(at(hourly.visibility, idx));
    var visText = "";
    if (vis !== null) {
        var v = f ? vis / 1609.344 : vis / 1000;
        visText = (v >= 10 ? String(Math.round(v)) : v.toFixed(1)) + (f ? " mi" : " km");
    }

    var uv = num(at(hourly.uv_index, idx));
    if (uv === null)
        uv = num(at(daily.uv_index_max, 0));

    var precip = num(cur.precipitation) || 0;
    var press = num(cur.pressure_msl);
    var hum = num(cur.relative_humidity_2m);

    var days = [];
    var dayCount = Math.min(3, (daily.time || []).length);
    for (var d = 0; d < dayCount; d++) {
        var iso = daily.time[d];
        days.push({
            label: dayLabel(iso, d),
            date: parseInt(String(iso).slice(8, 10), 10) || 0,
            iconName: iconFor(at(daily.weather_code, d), false),
            condition: describe(at(daily.weather_code, d)),
            high: temp(at(daily.temperature_2m_max, d)) + "°",
            low: temp(at(daily.temperature_2m_min, d)) + "°",
            rain: Math.round(num(at(daily.precipitation_probability_max, d)) || 0)
        });
    }

    // The next eight readings, three hours apart (the popup and the card were
    // laid out for eight three-hour notes).
    var hours = [];
    var start = idx >= 0 ? idx : 0;
    for (var n = 0; n < 8; n++) {
        var j = start + n * 3;
        if (j >= times.length)
            break;
        var hh = parseInt(String(times[j]).slice(11, 13), 10) || 0;
        var use24h = !opts || opts.use24h === true;
        hours.push({
            label: use24h ? pad(hh) + ":00" : (hh % 12 || 12) + (hh < 12 ? " AM" : " PM"),
            iconName: iconFor(at(hourly.weather_code, j), at(hourly.is_day, j) === 0),
            condition: describe(at(hourly.weather_code, j)),
            temp: temp(at(hourly.temperature_2m, j)) + "°",
            feels: temp(at(hourly.apparent_temperature, j)) + "°",
            rain: Math.round(num(at(hourly.precipitation_probability, j)) || 0)
        });
    }

    return {
        temperatureText: temp(cur.temperature_2m) + unit,
        conditionText: describe(cur.weather_code),
        iconName: iconFor(cur.weather_code, night),
        feelsLikeText: temp(cur.apparent_temperature) + unit,
        humidityText: hum === null ? "" : Math.round(hum) + "%",
        windText: windText,
        pressureText: press === null ? "" : Math.round(press) + " hPa",
        visibilityText: visText,
        uvText: uv === null ? "" : String(Math.round(uv)),
        precipText: f ? (precip / 25.4).toFixed(2) + " in" : precip.toFixed(1) + " mm",
        sunriseText: clock12(at(daily.sunrise, 0)),
        sunsetText: clock12(at(daily.sunset, 0)),
        forecast: days,
        hourly: hours
    };
}
