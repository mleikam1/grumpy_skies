import * as assert from "node:assert/strict";
import {test} from "node:test";

import {
  normalizeCurrentWeather,
  parseLatitude,
  parseLongitude,
  parseUnits,
  safeUpstreamCode,
  safeUpstreamMessage,
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

test("maps Current Weather API 2.5 response into normalized DTO", () => {
  const dto = normalizeCurrentWeather(
    {
      coord: {
        lat: 38.8672283,
        lon: -94.6520357,
      },
      weather: [
        {
          id: 800,
          main: "Clear",
          description: "clear sky",
          icon: "01d",
        },
      ],
      main: {
        temp: 82.4,
        feels_like: 84.1,
        pressure: 1012,
        humidity: 58,
      },
      visibility: 10000,
      wind: {
        speed: 7.5,
        deg: 190,
        gust: 12.1,
      },
      rain: {"1h": 0.2},
      dt: 1782043200,
      sys: {
        sunrise: 1782030000,
        sunset: 1782085200,
      },
      timezone: -18000,
    },
    "imperial",
  );

  assert.equal(dto.latitude, 38.8672283);
  assert.equal(dto.longitude, -94.6520357);
  assert.equal(dto.timezoneOffset, -18000);
  assert.equal(dto.observedAt, 1782043200);
  assert.equal(dto.sunrise, 1782030000);
  assert.equal(dto.sunset, 1782085200);
  assert.equal(dto.temp, 82.4);
  assert.equal(dto.feelsLike, 84.1);
  assert.equal(dto.pressure, 1012);
  assert.equal(dto.humidity, 58);
  assert.equal(dto.windSpeed, 7.5);
  assert.equal(dto.windGust, 12.1);
  assert.equal(dto.windDeg, 190);
  assert.equal(dto.rain1h, 0.2);
  assert.equal(dto.weatherId, 800);
  assert.equal(dto.weatherMain, "Clear");
  assert.equal(dto.weatherDescription, "clear sky");
  assert.equal(dto.weatherIcon, "01d");
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
    "/data/2.5/weather",
    {lat: 38.861, lon: -94.652, units: "imperial", lang: "en"},
    "weather/current",
  );
  const sameBucket = weatherCacheKey(
    "/data/2.5/weather",
    {lat: 38.864, lon: -94.654, units: "imperial", lang: "en"},
    "weather/current",
  );
  const metric = weatherCacheKey(
    "/data/2.5/weather",
    {lat: 38.861, lon: -94.652, units: "metric", lang: "en"},
    "weather/current",
  );

  assert.equal(first, sameBucket);
  assert.notEqual(first, metric);
  assert.match(first, /lat=38\.86/);
  assert.match(first, /lon=-94\.65/);
});

test("classifies OpenWeather One Call auth and subscription errors safely", () => {
  const subscriptionBody = JSON.stringify({
    cod: 401,
    message: "One Call API 4.0 subscription required",
  });
  const invalidKeyBody = JSON.stringify({
    cod: 401,
    message: "Invalid API key",
  });

  assert.equal(
    safeUpstreamCode(401, subscriptionBody),
    "openweather_one_call_access_denied",
  );
  assert.match(
    safeUpstreamMessage(401, subscriptionBody),
    /One Call API 4\.0/,
  );
  assert.equal(safeUpstreamCode(401, invalidKeyBody), "openweather_key_rejected");
  assert.match(safeUpstreamMessage(401, invalidKeyBody), /OPENWEATHER_API_KEY/);
  assert.doesNotMatch(safeUpstreamMessage(401, invalidKeyBody), /appid/i);
});

test("classifies OpenWeather radar access errors separately", () => {
  const subscriptionBody = JSON.stringify({
    cod: 403,
    message: "Your plan does not include this map layer",
  });

  assert.equal(
    safeUpstreamCode(403, subscriptionBody, "maps"),
    "openweather_radar_access_denied",
  );
  assert.match(
    safeUpstreamMessage(403, subscriptionBody, "maps"),
    /radar maps/,
  );
  assert.doesNotMatch(
    safeUpstreamMessage(403, subscriptionBody, "maps"),
    /appid/i,
  );
});
