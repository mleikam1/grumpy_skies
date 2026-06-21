import * as assert from "node:assert/strict";
import {test} from "node:test";

import {
  normalizeCurrentWeather,
  parseLatitude,
  parseLongitude,
  parseUnits,
  weatherCacheKey,
} from "./index";

test("validates latitude, longitude, and units", () => {
  assert.equal(parseLatitude("38.8672283"), 38.8672283);
  assert.equal(parseLongitude("-94.6520357"), -94.6520357);
  assert.equal(parseUnits(undefined), "imperial");
  assert.equal(parseUnits("metric"), "metric");

  assert.throws(() => parseLatitude("91"), /Latitude/);
  assert.throws(() => parseLongitude("-181"), /Longitude/);
  assert.throws(() => parseUnits("banana"), /Units/);
});

test("maps One Call 4.0 current data[0] into normalized DTO", () => {
  const dto = normalizeCurrentWeather(
    {
      lat: 38.8672283,
      lon: -94.6520357,
      timezone: "America/Chicago",
      timezone_offset: -18000,
      data: [
        {
          dt: 1782043200,
          sunrise: 1782030000,
          sunset: 1782085200,
          temp: 76,
          feels_like: 78,
          pressure: 1014,
          humidity: 64,
          dew_point: 63,
          uvi: 7.2,
          clouds: 40,
          visibility: 10000,
          wind_speed: 12,
          wind_gust: 19,
          wind_deg: 225,
          rain: {"1h": 1.27},
          weather: [
            {
              id: 500,
              main: "Rain",
              description: "light rain",
              icon: "10d",
            },
          ],
          alerts: ["alert-1"],
        },
      ],
    },
    "imperial",
  );

  assert.equal(dto.latitude, 38.8672283);
  assert.equal(dto.longitude, -94.6520357);
  assert.equal(dto.timezone, "America/Chicago");
  assert.equal(dto.timezoneOffset, -18000);
  assert.equal(dto.observedAt, 1782043200);
  assert.equal(dto.sourceUpdatedAt, 1782043200);
  assert.equal(dto.temp, 76);
  assert.equal(dto.feelsLike, 78);
  assert.equal(dto.rain1h, 1.27);
  assert.equal(dto.snow1h, null);
  assert.equal(dto.weatherId, 500);
  assert.equal(dto.weatherMain, "Rain");
  assert.equal(dto.weatherDescription, "light rain");
  assert.equal(dto.weatherIcon, "10d");
  assert.deepEqual(dto.alertIds, ["alert-1"]);
  assert.equal(dto.units, "imperial");
  assert.equal(typeof dto.fetchedAt, "string");
});

test("handles missing optional current weather fields safely", () => {
  const dto = normalizeCurrentWeather({
    lat: 1,
    lon: 2,
    data: [
      {
        dt: 1782043200,
        temp: 70,
        feels_like: 70,
        weather: [],
      },
    ],
  });

  assert.equal(dto.windGust, null);
  assert.equal(dto.rain1h, null);
  assert.equal(dto.snow1h, null);
  assert.deepEqual(dto.alertIds, []);
});

test("weather cache key rounds location and includes units", () => {
  const first = weatherCacheKey(
    "/data/4.0/onecall/current",
    {lat: 38.861, lon: -94.652, units: "imperial", lang: "en"},
    "weather/current",
  );
  const sameBucket = weatherCacheKey(
    "/data/4.0/onecall/current",
    {lat: 38.864, lon: -94.654, units: "imperial", lang: "en"},
    "weather/current",
  );
  const metric = weatherCacheKey(
    "/data/4.0/onecall/current",
    {lat: 38.861, lon: -94.652, units: "metric", lang: "en"},
    "weather/current",
  );

  assert.equal(first, sameBucket);
  assert.notEqual(first, metric);
  assert.match(first, /lat=38\.86/);
  assert.match(first, /lon=-94\.65/);
});
