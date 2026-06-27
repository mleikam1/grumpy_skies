import * as assert from "node:assert/strict";
import {test} from "node:test";

import {
  normalizeCurrentWeather,
  normalizeForecastWeather,
  normalizeLegacyForecastWeather,
  normalizeNwsForecastWeather,
  normalizeOneCall3ForecastWeather,
  normalizeOneCallTimelineForecast,
  openWeatherRadarTilePath,
  parseLatitude,
  parseLongitude,
  parseUnits,
  roundToNearestPastFiveMinuteUnix,
  safeUpstreamCode,
  safeUpstreamMessage,
  webMercatorTileBbox,
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

test("maps One Call bundled forecast arrays without truncating daily data", () => {
  const dto = normalizeForecastWeather(
    {
      lat: 38.8672283,
      lon: -94.6520357,
      timezone: "America/Chicago",
      timezone_offset: -18000,
      current: {
        dt: 1782043200,
        sunrise: 1782030000,
        sunset: 1782085200,
        temp: 76,
        feels_like: 78,
        humidity: 64,
        weather: [
          {
            id: 500,
            main: "Rain",
            description: "light rain",
            icon: "10d",
          },
        ],
      },
      minutely: [
        {
          dt: 1782043260,
          precipitation: 1.27,
        },
      ],
      hourly: Array.from({length: 48}, (_, index) => ({
        dt: 1782043200 + index * 3600,
        temp: 76 + index,
        feels_like: 78 + index,
        humidity: 64,
        pop: index / 20,
        weather: [
          {
            id: 801,
            main: "Clouds",
            description: "few clouds",
            icon: "02d",
          },
        ],
      })),
      daily: Array.from({length: 8}, (_, index) => ({
        dt: 1782043200 + index * 86400,
        temp: {
          min: 60 + index,
          max: 80 + index,
        },
        pop: index / 10,
        weather: [
          {
            id: 803,
            main: "Clouds",
            description: "broken clouds",
            icon: "04d",
          },
        ],
      })),
    },
    "imperial",
  );
  const hourly = dto.hourly as Record<string, unknown>[];
  const daily = dto.daily as Record<string, unknown>[];
  const firstDailyTemp = daily[0].temp as Record<string, unknown>;

  assert.equal(dto.timezone, "America/Chicago");
  assert.equal(dto.timezoneOffset, -18000);
  assert.equal(hourly.length, 48);
  assert.equal(daily.length, 8);
  assert.equal(hourly[0].temp, 76);
  assert.equal(hourly[47].temp, 123);
  assert.equal(daily[0].date, "2026-06-21T00:00:00.000");
  assert.equal(firstDailyTemp.min, 60);
  assert.equal(firstDailyTemp.max, 80);
  assert.equal(daily[0].condition, "broken clouds");
});

test("maps One Call 4.0 timeline data arrays into forecast DTOs", () => {
  const currentRaw = {
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
        humidity: 64,
        weather: [
          {
            id: 500,
            main: "Rain",
            description: "light rain",
            icon: "10d",
          },
        ],
      },
    ],
  };
  const hourlyRaw = {
    lat: 38.8672283,
    lon: -94.6520357,
    timezone: "America/Chicago",
    timezone_offset: -18000,
    data: Array.from({length: 20}, (_, index) => ({
      dt: 1782043200 + index * 3600,
      temp: 76 + index,
      feels_like: 78 + index,
      pressure: 1014,
      humidity: 64,
      dew_point: 63,
      uvi: 7.2,
      clouds: 40,
      visibility: 10000,
      wind_speed: 12,
      wind_gust: 19,
      wind_deg: 225,
      pop: 0.2,
      rain: {"1h": 0.08},
      weather: [
        {
          id: 801,
          main: "Clouds",
          description: "few clouds",
          icon: "02d",
        },
      ],
    })),
  };
  const dailyRaw = {
    lat: 38.8672283,
    lon: -94.6520357,
    timezone: "America/Chicago",
    timezone_offset: -18000,
    data: Array.from({length: 10}, (_, index) => ({
      dt: 1782043200 + index * 86400,
      sunrise: 1782030000 + index * 86400,
      sunset: 1782085200 + index * 86400,
      moonrise: 1782090000 + index * 86400,
      moonset: 1782120000 + index * 86400,
      moon_phase: 0.42,
      temp: {
        day: 76 + index,
        min: 60 + index,
        max: 82 + index,
        night: 68 + index,
        eve: 74 + index,
        morn: 62 + index,
      },
      feels_like: {
        day: 78 + index,
        night: 69 + index,
        eve: 75 + index,
        morn: 63 + index,
      },
      pressure: 1014,
      humidity: 64,
      dew_point: 63,
      wind_speed: 12,
      wind_gust: 19,
      wind_deg: 225,
      clouds: 40,
      pop: 0.35,
      uvi: 7.2,
      weather: [
        {
          id: 803,
          main: "Clouds",
          description: "broken clouds",
          icon: "04d",
        },
      ],
    })),
  };

  const dto = normalizeOneCallTimelineForecast(
    currentRaw,
    hourlyRaw,
    dailyRaw,
    "imperial",
  );
  const hourly = dto.hourly as Record<string, unknown>[];
  const daily = dto.daily as Record<string, unknown>[];
  const hourlyTimeline = dto.hourlyTimeline as Record<string, unknown>;
  const dailyTimeline = dto.dailyTimeline as Record<string, unknown>;
  const hourlyTimelineData =
    hourlyTimeline.data as Record<string, unknown>[];
  const dailyTimelineData = dailyTimeline.data as Record<string, unknown>[];
  const firstDailyTemp = daily[0].temp as Record<string, unknown>;
  const firstHourlyWeather = hourly[0].weather as Record<string, unknown>;
  const firstDailyWeather = daily[0].weather as Record<string, unknown>;

  assert.equal(dto.timezone, "America/Chicago");
  assert.equal(dto.timezoneOffset, -18000);
  assert.equal(hourly.length, 20);
  assert.equal(daily.length, 10);
  assert.equal(hourlyTimelineData.length, 20);
  assert.equal(dailyTimelineData.length, 10);
  assert.equal(hourly[0].temp, 76);
  assert.equal(hourly[0].precipitationProbability, 0.2);
  assert.equal(hourly[0].rain1h, 0.08);
  assert.equal(firstHourlyWeather.icon, "02d");
  assert.equal(firstDailyTemp.min, 60);
  assert.equal(firstDailyTemp.max, 82);
  assert.equal(daily[0].pop, 0.35);
  assert.equal(firstDailyWeather.description, "broken clouds");
});

test("maps One Call 4.0 timeline failures into forecast error metadata", () => {
  const dto = normalizeOneCallTimelineForecast(
    {
      lat: 38.8672283,
      lon: -94.6520357,
      timezone: "America/Chicago",
      timezone_offset: -18000,
      data: [
        {
          dt: 1782043200,
          temp: 76,
          feels_like: 78,
          humidity: 64,
          weather: [
            {
              id: 800,
              main: "Clear",
              description: "clear sky",
              icon: "01d",
            },
          ],
        },
      ],
    },
    null,
    null,
    "imperial",
    {
      hourly: {
        endpointType: "hourly",
        status: 502,
        code: "openweather_one_call_access_denied",
        message: "OpenWeather rejected the server key for One Call API 4.0.",
      },
      daily: {
        endpointType: "daily",
        status: 502,
        code: "openweather_one_call_access_denied",
        message: "OpenWeather rejected the server key for One Call API 4.0.",
      },
    },
  );
  const hourly = dto.hourly as Record<string, unknown>[];
  const daily = dto.daily as Record<string, unknown>[];
  const errors = dto.forecastErrors as Record<string, unknown>;
  const hourlyError = errors.hourly as Record<string, unknown>;
  const dailyError = errors.daily as Record<string, unknown>;

  assert.equal(hourly.length, 0);
  assert.equal(daily.length, 0);
  assert.equal(hourlyError.code, "openweather_one_call_access_denied");
  assert.equal(dailyError.code, "openweather_one_call_access_denied");
});

test("maps One Call 3.0 fallback forecast into timeline-compatible DTOs", () => {
  const dto = normalizeOneCall3ForecastWeather(
    {
      lat: 38.8672283,
      lon: -94.6520357,
      timezone: "America/Chicago",
      timezone_offset: -18000,
      current: {
        dt: 1782043200,
        sunrise: 1782030000,
        sunset: 1782085200,
        temp: 76,
        feels_like: 78,
        humidity: 64,
        weather: [
          {
            id: 800,
            main: "Clear",
            description: "clear sky",
            icon: "01d",
          },
        ],
      },
      hourly: Array.from({length: 48}, (_, index) => ({
        dt: 1782043200 + index * 3600,
        temp: 76 + index,
        feels_like: 78 + index,
        humidity: 64,
        pop: 0.2,
        weather: [
          {
            id: 801,
            main: "Clouds",
            description: "few clouds",
            icon: "02d",
          },
        ],
      })),
      daily: Array.from({length: 8}, (_, index) => ({
        dt: 1782043200 + index * 86400,
        temp: {
          min: 60 + index,
          max: 82 + index,
        },
        pop: 0.35,
        weather: [
          {
            id: 803,
            main: "Clouds",
            description: "broken clouds",
            icon: "04d",
          },
        ],
      })),
    },
    "imperial",
  );
  const hourly = dto.hourly as Record<string, unknown>[];
  const daily = dto.daily as Record<string, unknown>[];
  const hourlyTimeline = dto.hourlyTimeline as Record<string, unknown>;
  const dailyTimeline = dto.dailyTimeline as Record<string, unknown>;

  assert.equal(dto.forecastSource, "openweather_onecall_3");
  assert.equal(hourly.length, 48);
  assert.equal(daily.length, 8);
  assert.equal((hourlyTimeline.data as unknown[]).length, 48);
  assert.equal((dailyTimeline.data as unknown[]).length, 8);
});

test("maps legacy 2.5 forecast data into hourly and aggregated daily DTOs", () => {
  const currentRaw = {
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
      temp: 76,
      feels_like: 78,
      humidity: 64,
    },
    wind: {
      speed: 10,
      deg: 180,
    },
    dt: 1782043200,
    timezone: -18000,
  };
  const legacyRaw = {
    city: {
      coord: {
        lat: 38.8672283,
        lon: -94.6520357,
      },
      timezone: -18000,
    },
    list: Array.from({length: 16}, (_, index) => ({
      dt: 1782043200 + index * 10800,
      main: {
        temp: 70 + index,
        temp_min: 68 + index,
        temp_max: 72 + index,
        feels_like: 71 + index,
        pressure: 1014,
        humidity: 64,
      },
      weather: [
        {
          id: 500,
          main: "Rain",
          description: "light rain",
          icon: "10d",
        },
      ],
      clouds: {
        all: 40,
      },
      wind: {
        speed: 12,
        gust: 18,
        deg: 225,
      },
      pop: 0.4,
      rain: {
        "3h": 0.12,
      },
    })),
  };

  const dto = normalizeLegacyForecastWeather(
    currentRaw,
    legacyRaw,
    null,
    "imperial",
  );
  const hourly = dto.hourly as Record<string, unknown>[];
  const daily = dto.daily as Record<string, unknown>[];
  const firstDailyTemp = daily[0].temp as Record<string, unknown>;

  assert.equal(dto.forecastSource, "openweather_legacy_2_5");
  assert.equal(hourly.length, 16);
  assert.ok(daily.length >= 2);
  assert.equal(hourly[0].temp, 70);
  assert.equal(hourly[0].precipitationProbability, 0.4);
  assert.equal(firstDailyTemp.min, 68);
  assert.equal(daily[0].pop, 0.4);
});

test("maps National Weather Service forecast periods into hourly and 7 daily DTOs", () => {
  const currentRaw = {
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
      temp: 76,
      feels_like: 78,
      humidity: 64,
    },
    wind: {
      speed: 10,
      deg: 180,
    },
    dt: 1782043200,
    timezone: -18000,
  };
  const pointsRaw = {
    properties: {
      timeZone: "America/Chicago",
      relativeLocation: {
        geometry: {
          coordinates: [-94.6520357, 38.8672283],
        },
        properties: {
          city: "Overland Park",
        },
      },
    },
  };
  const hourlyRaw = {
    properties: {
      periods: Array.from({length: 72}, (_, index) => ({
        startTime: new Date(Date.UTC(2026, 5, 27, index)).toISOString(),
        temperature: 70 + (index % 12),
        temperatureUnit: "F",
        windSpeed: "8 to 12 mph",
        windDirection: "S",
        shortForecast: index % 3 === 0 ? "Chance Rain Showers" : "Mostly Sunny",
        probabilityOfPrecipitation: {
          value: index % 3 === 0 ? 40 : 5,
        },
        relativeHumidity: {
          value: 65,
        },
      })),
    },
  };
  const dailyRaw = {
    properties: {
      periods: Array.from({length: 14}, (_, index) => {
        const day = Math.floor(index / 2);
        const daytime = index % 2 === 0;
        return {
          startTime: `2026-06-${String(27 + day).padStart(2, "0")}T${daytime ? "06" : "18"}:00:00-05:00`,
          isDaytime: daytime,
          temperature: daytime ? 82 + day : 62 + day,
          temperatureUnit: "F",
          windSpeed: "10 mph",
          windDirection: "SW",
          shortForecast: daytime ? "Mostly Sunny" : "Partly Cloudy",
          probabilityOfPrecipitation: {
            value: daytime ? 20 : 10,
          },
        };
      }),
    },
  };

  const dto = normalizeNwsForecastWeather(
    currentRaw,
    pointsRaw,
    hourlyRaw,
    dailyRaw,
    "imperial",
  );
  const hourly = dto.hourly as Record<string, unknown>[];
  const daily = dto.daily as Record<string, unknown>[];
  const firstDailyTemp = daily[0].temp as Record<string, unknown>;

  assert.equal(dto.forecastSource, "nws_api");
  assert.equal(dto.timezone, "America/Chicago");
  assert.equal(hourly.length, 72);
  assert.equal(daily.length, 7);
  assert.equal(hourly[0].precipitationProbability, 40);
  assert.equal(hourly[0].windSpeed, 12);
  assert.equal(firstDailyTemp.max, 82);
  assert.equal(firstDailyTemp.min, 62);
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

test("NOAA radar helpers snap to 5 minutes and build Web Mercator bboxes", () => {
  assert.equal(
    roundToNearestPastFiveMinuteUnix(new Date("2026-06-26T17:07:59Z")),
    1782493500,
  );

  const bbox = webMercatorTileBbox(6, 15, 24);
  assert.equal(Math.round(bbox.xmin), -10644926);
  assert.equal(Math.round(bbox.ymin), 4383205);
  assert.equal(Math.round(bbox.xmax), -10018754);
  assert.equal(Math.round(bbox.ymax), 5009377);
});

test("OpenWeather radar tile paths use US FutureCast and global forecast products", () => {
  assert.equal(
    openWeatherRadarTilePath("openweather_futurecast", 6, 15, 24),
    "/maps/2.0/radar/us/forecast/6/15/24",
  );
  assert.equal(
    openWeatherRadarTilePath("openweather_global", 3, 2, 4),
    "/maps/2.0/radar/forecast/3/2/4",
  );
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
