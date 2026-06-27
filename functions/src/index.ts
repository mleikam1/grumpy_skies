import {initializeApp} from "firebase-admin/app";
import {logger} from "firebase-functions";
import {defineSecret, defineString} from "firebase-functions/params";
import {onRequest, Request} from "firebase-functions/v2/https";
import type {Response} from "express";

initializeApp();

export const openWeatherApiKey = defineSecret("OPENWEATHER_API_KEY");
export const enableGlobalForecastRadar = defineString(
  "OPENWEATHER_ENABLE_GLOBAL_FORECAST_RADAR",
  {default: "false"},
);

const openWeatherApiBase = "https://api.openweathermap.org";
const openWeatherMapBase = "https://maps.openweathermap.org";
const noaaRadarImageServerBase =
  "https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer";
const tenMinutesSeconds = 10 * 60;
const fiveMinutesSeconds = 5 * 60;
const noaaRadarHistorySeconds = 90 * 60;
const openWeatherRadarHistorySeconds = 120 * 60;
const sixHoursSeconds = 6 * 60 * 60;
const noaaFrameQueryRecordCount = 240;
const noaaFrameClusterSeconds = 120;
const weatherCacheControl = "public, max-age=300, stale-while-revalidate=300";
const radarFallbackCacheControl = "public, max-age=30";
const openWeatherTimeoutMs = 8000;
const authFailureTtlMs = 5 * 60 * 1000;
const transparentRadarTilePng = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAABFUlEQVR42u3BMQEAAADCoPVP7WsIoAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAeAMBPAAB2ClDBAAAAABJRU5ErkJggg==",
  "base64",
);

type RadarMode = "us-forecast" | "futurecast" | "global";
type RadarProduct = "us" | "global";
type RadarSource =
  "noaa_mrms" |
  "openweather_futurecast" |
  "openweather_global";
type OpenWeatherRadarSource = Exclude<RadarSource, "noaa_mrms">;

type JsonRecord = Record<string, unknown>;
type CacheEntry = {
  expiresAtMs: number;
  value: unknown;
};
type ErrorCacheEntry = {
  expiresAtMs: number;
  error: PublicHttpError;
};
type WebMercatorBbox = {
  xmin: number;
  ymin: number;
  xmax: number;
  ymax: number;
};
type RadarImageDiagnostics = {
  source: RadarSource;
  z: number;
  x: number;
  y: number;
  frameTimestamp: number;
  upstreamStatus: number | null;
  upstreamContentType: string | null;
  upstreamContentLength: number | null;
  firstBytesHex: string;
  isPng: boolean;
  isJpeg: boolean;
  isImage: boolean;
};
type NoaaRadarMetadata = {
  latestFrameTimestamp: number;
  availableFrameCount: number;
  availableFrom: number;
  availableTo: number;
  updateIntervalSeconds: number | null;
  availableTimestamps: number[];
  diagnosticMessage: string | null;
};
type RadarFrameProbe = {
  source: RadarSource;
  frameTimestamp: number;
  z: number;
  x: number;
  y: number;
  renderable: boolean;
  validImageResponses: number;
  transparentFallbackTileResponses: number;
  upstreamErrors: number;
  fallbackCode: string | null;
  humanReadableMessage: string | null;
  diagnostics: RadarImageDiagnostics | null;
};

const jsonCache = new Map<string, CacheEntry>();
const jsonInflight = new Map<string, Promise<unknown>>();
const upstreamAuthFailures = new Map<string, ErrorCacheEntry>();

class PublicHttpError extends Error {
  constructor(
    readonly status: number,
    readonly safeMessage: string,
    readonly safeCode = "weather_error",
  ) {
    super(safeMessage);
  }
}

export const weatherBackendHealth = onRequest(
  {
    region: "us-central1",
    secrets: [openWeatherApiKey],
  },
  (_request, response) => {
    // Secret-bound weather functions can call openWeatherApiKey.value() here.
    // Never return, log, or send the secret value to the Flutter client.
    response.json({
      ok: true,
      provider: "openweather",
    });
  },
);

export const api = onRequest(
  {
    region: "us-central1",
    secrets: [openWeatherApiKey],
    cors: true,
    timeoutSeconds: 60,
  },
  async (request, response) => {
    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "GET") {
      sendJson(response, 405, {
        error: {
          message: "This weather endpoint only supports GET requests.",
        },
      });
      return;
    }

    const path = normalizedApiPath(request);

    try {
      if (path === "/health") {
        sendJson(response, 200, {
          ok: true,
          service: "grumpy-skies-api",
          timestamp: new Date().toISOString(),
        });
        return;
      }

      if (path === "/location/geocode") {
        await handleGeocode(request, response);
        return;
      }

      if (path === "/location/zip") {
        await handleZip(request, response);
        return;
      }

      if (path === "/location/reverse") {
        await handleReverse(request, response);
        return;
      }

      if (path === "/weather/current") {
        await handleCurrentWeather(request, response);
        return;
      }

      if (path === "/weather/forecast") {
        await handleForecastWeather(request, response);
        return;
      }

      if (path === "/weather/minute") {
        await handleMinuteWeather(request, response);
        return;
      }

      if (path === "/weather/timeline15") {
        await handleTimelineWeather(request, response, "15min");
        return;
      }

      if (path === "/weather/hourly") {
        await handleTimelineWeather(request, response, "1h");
        return;
      }

      if (path === "/radarTile") {
        const product = parseRadarProduct(requiredQuery(request, "product"));
        await handleRadarTile(
          request,
          response,
          radarModeForProduct(product),
          requiredQuery(request, "z"),
          requiredQuery(request, "x"),
          requiredQuery(request, "y"),
        );
        return;
      }

      if (path === "/radarFrames") {
        await handleRadarFrames(request, response);
        return;
      }

      if (path === "/radar/noaaFrames") {
        await handleNoaaFrames(request, response);
        return;
      }

      if (path === "/radar/futureFrames") {
        await handleFutureFrames(request, response);
        return;
      }

      if (path === "/radar/tile") {
        await handleUnifiedRadarTile(request, response);
        return;
      }

      if (path === "/radarHealth") {
        await handleRadarHealth(request, response);
        return;
      }

      const alertMatch = path.match(/^\/weather\/alert\/([A-Za-z0-9_-]+)$/);
      if (alertMatch) {
        await handleAlert(alertMatch[1], response);
        return;
      }

      const tileMatch = path.match(
        /^\/radar\/tile\/(us-forecast|futurecast|global)\/(\d+)\/(\d+)\/(\d+)\.png$/,
      );
      if (tileMatch) {
        await handleRadarTile(
          request,
          response,
          tileMatch[1] as RadarMode,
          tileMatch[2],
          tileMatch[3],
          tileMatch[4],
        );
        return;
      }

      sendJson(response, 404, {
        error: {
          code: "ROUTE_NOT_FOUND",
          message: "Weather endpoint not found.",
        },
      });
    } catch (error) {
      handleRouteError(response, path, error);
    }
  },
);

export function roundToNearestPastTenMinuteUnix(date = new Date()): number {
  return Math.floor(date.getTime() / 1000 / tenMinutesSeconds) *
    tenMinutesSeconds;
}

export function roundToNearestPastFiveMinuteUnix(date = new Date()): number {
  return Math.floor(date.getTime() / 1000 / fiveMinutesSeconds) *
    fiveMinutesSeconds;
}

async function handleGeocode(request: Request, response: Response) {
  const q = requiredQuery(request, "q").trim();
  if (q.length < 2 || q.length > 120) {
    throw new PublicHttpError(
      400,
      "Enter a city search between 2 and 120 characters.",
    );
  }

  const limit = parseLimit(queryParam(request, "limit"));
  const raw = await openWeatherJson(
    "/geo/1.0/direct",
    {q, limit},
    "location/geocode",
  );
  const records = Array.isArray(raw) ? raw : [];
  const locations = records
    .map((item) => normalizeLocation(item, "city"))
    .filter((item): item is JsonRecord => item !== null);

  sendJson(response, 200, {locations});
}

async function handleZip(request: Request, response: Response) {
  const zip = requiredQuery(request, "zip").trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9 -]{1,18}[A-Za-z0-9]$/.test(zip)) {
    throw new PublicHttpError(400, "Enter a valid ZIP or postal code.");
  }

  const country = (queryParam(request, "country") ?? "US")
    .trim()
    .toUpperCase();
  if (!/^[A-Z]{2}$/.test(country)) {
    throw new PublicHttpError(400, "Enter a two-letter country code.");
  }

  const raw = await openWeatherJson(
    "/geo/1.0/zip",
    {zip: `${zip},${country}`},
    "location/zip",
  );
  const location = normalizeLocation(raw, "zip");
  if (location === null) {
    throw new PublicHttpError(
      404,
      "No location was found for that postal code.",
    );
  }

  sendJson(response, 200, {location});
}

async function handleReverse(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const raw = await openWeatherJson(
    "/geo/1.0/reverse",
    {lat, lon, limit: 1},
    "location/reverse",
  );
  const first = Array.isArray(raw) ? raw[0] : raw;
  const location = normalizeLocation(first, "device", lat, lon);
  if (location === null) {
    sendJson(response, 200, {
      location: {
        name: "Current location",
        country: "US",
        lat,
        lon,
        source: "device",
      },
    });
    return;
  }

  sendJson(response, 200, {location});
}

async function handleCurrentWeather(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const units = parseUnits(queryParam(request, "units"));
  let raw: unknown;
  try {
    raw = await openWeatherJson(
      "/data/4.0/onecall/current",
      {lat, lon, units, lang: "en"},
      "weather/current",
    );
  } catch (error) {
    if (!isOneCallAccessDenied(error)) {
      throw error;
    }

    logger.warn("OpenWeather One Call current unavailable; using legacy current weather", {
      code: (error as PublicHttpError).safeCode,
    });
    raw = await openWeatherJson(
      "/data/2.5/weather",
      {lat, lon, units, lang: "en"},
      "weather/current/fallback",
    );
  }

  sendJson(response, 200, {
    current: normalizeCurrentWeather(raw, units),
  }, weatherCacheControl);
}

async function handleForecastWeather(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const units = parseUnits(queryParam(request, "units"));
  const currentRaw = await fetchCurrentWeatherForForecast(lat, lon, units);
  const [hourlyResult, dailyResult] = await Promise.all([
    fetchForecastTimeline(
      "/data/4.0/onecall/timeline/1h",
      {lat, lon, units, lang: "en"},
      "weather/forecast/hourly",
      "hourly",
    ),
    fetchForecastTimeline(
      "/data/4.0/onecall/timeline/1day",
      {lat, lon, units, lang: "en"},
      "weather/forecast/daily",
      "daily",
    ),
  ]);
  const normalized = normalizeOneCallTimelineForecast(
    currentRaw,
    hourlyResult.raw,
    dailyResult.raw,
    units,
    forecastErrorsFor(hourlyResult.error, dailyResult.error),
  );
  logger.info("OpenWeather forecast timelines normalized", {
    hourlyStatus: hourlyResult.status,
    hourlyDataLength: hourlyResult.dataLength,
    hourlyTimezone: hourlyResult.timezone,
    hourlyErrorCode: stringOrNull(hourlyResult.error?.code),
    dailyStatus: dailyResult.status,
    dailyDataLength: dailyResult.dataLength,
    dailyTimezone: dailyResult.timezone,
    dailyErrorCode: stringOrNull(dailyResult.error?.code),
  });

  sendJson(
    response,
    200,
    normalized,
    weatherCacheControl,
  );
}

type ForecastTimelineResult = {
  raw: unknown | null;
  status: number;
  dataLength: number;
  timezone: string | null;
  error: JsonRecord | null;
};

async function fetchForecastTimeline(
  pathname: string,
  params: Record<string, string | number | undefined>,
  routeLabel: string,
  endpointType: "hourly" | "daily",
): Promise<ForecastTimelineResult> {
  try {
    const raw = await openWeatherJson(pathname, params, routeLabel);
    return {
      raw,
      status: 200,
      dataLength: responseDataLength(raw) ?? 0,
      timezone: responseTimezone(raw),
      error: null,
    };
  } catch (error) {
    const safeError = forecastTimelineError(endpointType, error);
    logger.warn("OpenWeather forecast timeline unavailable", {
      endpointType,
      status: safeError.status,
      code: safeError.code,
      message: safeError.message,
    });
    return {
      raw: null,
      status: numberOrNull(safeError.status) ?? 500,
      dataLength: 0,
      timezone: null,
      error: safeError,
    };
  }
}

function forecastTimelineError(
  endpointType: "hourly" | "daily",
  error: unknown,
): JsonRecord {
  if (error instanceof PublicHttpError) {
    return {
      endpointType,
      status: error.status,
      code: error.safeCode,
      message: error.safeMessage,
    };
  }

  return {
    endpointType,
    status: 500,
    code: "openweather_timeline_error",
    message: "Forecast timeline data is temporarily unavailable.",
  };
}

function forecastErrorsFor(
  hourlyError: JsonRecord | null,
  dailyError: JsonRecord | null,
): JsonRecord {
  const errors: JsonRecord = {};
  if (hourlyError !== null) {
    errors.hourly = hourlyError;
  }
  if (dailyError !== null) {
    errors.daily = dailyError;
  }
  return errors;
}

async function fetchCurrentWeatherForForecast(
  lat: number,
  lon: number,
  units: "imperial" | "metric" | "standard",
): Promise<unknown> {
  try {
    return await openWeatherJson(
      "/data/4.0/onecall/current",
      {lat, lon, units, lang: "en"},
      "weather/forecast/current",
    );
  } catch (error) {
    if (!isOneCallAccessDenied(error)) {
      throw error;
    }

    logger.warn(
      "OpenWeather One Call current unavailable in forecast aggregator; using legacy current weather",
      {
        code: (error as PublicHttpError).safeCode,
      },
    );
    return openWeatherJson(
      "/data/2.5/weather",
      {lat, lon, units, lang: "en"},
      "weather/forecast/current/fallback",
    );
  }
}

async function handleMinuteWeather(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const units = parseUnits(queryParam(request, "units"));
  const raw = await openWeatherJson(
    "/data/4.0/onecall/timeline/1min",
    {lat, lon, units, lang: "en"},
    "weather/minute",
  );

  sendJson(response, 200, {
    minutes: normalizeMinutePrecipitation(raw, units),
  }, weatherCacheControl);
}

async function handleTimelineWeather(
  request: Request,
  response: Response,
  step: "15min" | "1h",
) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const units = parseUnits(queryParam(request, "units"));
  const raw = await openWeatherJson(
    `/data/4.0/onecall/timeline/${step}`,
    {lat, lon, units, lang: "en"},
    `weather/timeline/${step}`,
  );
  const record = asRecord(raw);
  const limit = step === "1h" ? 20 : 50;

  sendJson(response, 200, {
    points: normalizeTimeline(raw, limit),
    next: sanitizeNext(record.next),
  }, weatherCacheControl);
}

async function handleAlert(alertId: string, response: Response) {
  if (!/^[A-Za-z0-9_-]{1,120}$/.test(alertId)) {
    throw new PublicHttpError(400, "That weather alert ID is invalid.");
  }

  const raw = await openWeatherJson(
    `/data/4.0/onecall/alert/${alertId}`,
    {},
    "weather/alert",
  );
  const record = pickDataRecord(raw);

  sendJson(response, 200, {
    alert: {
      sender_name: stringOrNull(record.sender_name ?? record.senderName),
      event: stringOrNull(record.event),
      start: numberOrNull(record.start),
      end: numberOrNull(record.end),
      description: stringOrNull(record.description),
    },
  }, weatherCacheControl);
}

async function handleRadarFrames(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const product = parseRadarFrameProduct(
    queryParam(request, "product") ?? "auto",
    lat,
    lon,
  );
  const mode = radarModeForProduct(product);
  if (mode === "us-forecast") {
    await handleNoaaFrames(request, response);
    return;
  }

  const latest = roundToNearestPastTenMinuteUnix();
  const forecastAvailable = false;
  const frames = buildRadarFrames(
    latest,
    forecastAvailable,
    tenMinutesSeconds,
    openWeatherRadarHistorySeconds,
    radarSourceForMode(mode),
  );
  sendJson(response, 200, {
    product,
    mode,
    source: radarSourceForMode(mode),
    productLabel: "Global precipitation radar",
    latestTimestamp: latest,
    minTimestamp: frames[0]?.timestamp ?? latest,
    maxTimestamp: frames[frames.length - 1]?.timestamp ?? latest,
    forecastAvailable,
    frames,
  }, "public, max-age=60");
}

async function handleNoaaFrames(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const metadata = await getNoaaRadarMetadata().catch((error): NoaaRadarMetadata => {
    logger.warn("NOAA radar metadata unavailable", {
      source: "noaa_mrms",
      message: error instanceof Error ? error.message : "Unknown error",
    });
    const latestFrameTimestamp = roundToNearestPastFiveMinuteUnix();
    return {
      latestFrameTimestamp,
      availableFrameCount: 0,
      availableFrom: latestFrameTimestamp - noaaRadarHistorySeconds,
      availableTo: latestFrameTimestamp,
      updateIntervalSeconds: fiveMinutesSeconds,
      availableTimestamps: [],
      diagnosticMessage:
        "NOAA metadata could not be loaded. Radar source temporarily unavailable.",
    };
  });
  const latest = metadata.latestFrameTimestamp;
  const timestamps = metadata.availableTimestamps.filter((timestamp) =>
    timestamp >= latest - noaaRadarHistorySeconds && timestamp <= latest);
  const frames = await buildValidatedRadarFrames({
    source: "noaa_mrms",
    lat,
    lon,
    latest,
    timestamps,
    nowLabel: "Latest",
  });
  const renderableFrames = frames.filter((frame) =>
    frame.renderable === true);

  sendJson(response, 200, {
    source: "noaa_mrms",
    mode: "us-forecast",
    product: "noaa_mrms_observed",
    productLabel: "NOAA MRMS radar",
    latestTimestamp:
      (renderableFrames[renderableFrames.length - 1]?.timestamp as number | undefined) ??
      latest,
    availableFrom: metadata.availableFrom,
    availableTo: metadata.availableTo,
    updateIntervalSeconds: metadata.updateIntervalSeconds,
    availableFrameCount: metadata.availableFrameCount,
    attribution: "Radar © NOAA/NWS MRMS",
    diagnosticMessage: metadata.diagnosticMessage,
    frames: renderableFrames,
    skippedFrames: frames.filter((frame) => frame.renderable !== true),
  }, "public, max-age=60");
}

async function handleFutureFrames(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const hours = parseFutureHours(queryParam(request, "hours"));
  const latest = roundToNearestPastTenMinuteUnix();
  const max = latest + hours * 60 * 60;
  const timestamps: number[] = [];
  for (let timestamp = latest; timestamp <= max; timestamp += tenMinutesSeconds) {
    timestamps.push(timestamp);
  }

  const firstProbe = await probeRadarFrame({
    source: "openweather_futurecast",
    lat,
    lon,
    timestamp: latest,
  });
  if (!firstProbe.renderable && isOpenWeatherRadarAccessFailure(firstProbe)) {
    logRadarFrameDiagnostics(radarFrameRecord({
      source: "openweather_futurecast",
      timestamp: latest,
      latest,
      nowLabel: "Now",
      probe: firstProbe,
    }));
    sendJson(response, 200, {
      source: "openweather_futurecast",
      mode: "futurecast",
      product: "openweather_radar_forecast",
      productLabel: "FutureCast precipitation",
      latestTimestamp: latest,
      maxTimestamp: max,
      futureCastAvailable: false,
      attribution: "Radar © OpenWeather",
      diagnosticMessage:
        "FutureCast requires OpenWeather precipitation forecast map access.",
      frames: [],
      skippedFrames: [
        radarFrameRecord({
          source: "openweather_futurecast",
          timestamp: latest,
          latest,
          nowLabel: "Now",
          probe: firstProbe,
        }),
      ],
    }, "public, max-age=60");
    return;
  }

  const remainingTimestamps = timestamps.slice(1);
  const remainingFrames = await buildValidatedRadarFrames({
    source: "openweather_futurecast",
    lat,
    lon,
    latest,
    timestamps: remainingTimestamps,
    nowLabel: "Now",
  });
  const frames = [
    radarFrameRecord({
      source: "openweather_futurecast",
      timestamp: latest,
      latest,
      nowLabel: "Now",
      probe: firstProbe,
    }),
    ...remainingFrames,
  ];
  const renderableFrames = frames.filter((frame) =>
    frame.renderable === true);

  sendJson(response, 200, {
    source: "openweather_futurecast",
    mode: "futurecast",
    product: "openweather_radar_forecast",
    productLabel: "FutureCast precipitation",
    latestTimestamp: latest,
    maxTimestamp: max,
    futureCastAvailable: renderableFrames.length > 0,
    attribution: "Radar © OpenWeather",
    diagnosticMessage: renderableFrames.length > 0 ?
      null :
      "FutureCast requires OpenWeather precipitation forecast map access.",
    frames: renderableFrames,
    skippedFrames: frames.filter((frame) => frame.renderable !== true),
  }, "public, max-age=60");
}

async function handleRadarTile(
  request: Request,
  response: Response,
  mode: RadarMode,
  zRaw: string,
  xRaw: string,
  yRaw: string,
) {
  if (mode === "us-forecast") {
    await handleNoaaRadarTile(request, response, zRaw, xRaw, yRaw);
    return;
  }

  await handleOpenWeatherRadarTile(request, response, mode, zRaw, xRaw, yRaw);
}

async function handleUnifiedRadarTile(request: Request, response: Response) {
  const source = parseRadarSource(requiredQuery(request, "source"));
  await handleRadarTile(
    request,
    response,
    radarModeForSource(source),
    requiredQuery(request, "z"),
    requiredQuery(request, "x"),
    requiredQuery(request, "y"),
  );
}

async function handleOpenWeatherRadarTile(
  request: Request,
  response: Response,
  mode: Exclude<RadarMode, "us-forecast">,
  zRaw: string,
  xRaw: string,
  yRaw: string,
) {
  const source = radarSourceForMode(mode) as OpenWeatherRadarSource;

  let z: number;
  let x: number;
  let y: number;
  let tm: number;

  try {
    z = parseInteger(zRaw, "z");
    x = parseInteger(xRaw, "x");
    y = parseInteger(yRaw, "y");

    if (z < 3 || z > 7) {
      throw new PublicHttpError(400, "Radar zoom must be between 3 and 7.");
    }

    const maxTile = 2 ** z;
    if (x < 0 || y < 0 || x >= maxTile || y >= maxTile) {
      throw new PublicHttpError(400, "Radar tile coordinates are invalid.");
    }

    tm = parseRadarTileTime(request);
    if (tm % tenMinutesSeconds !== 0) {
      throw new PublicHttpError(
        400,
        "Radar time must be snapped to a 10-minute UTC step.",
      );
    }

    const latest = roundToNearestPastTenMinuteUnix();
    const min = mode === "futurecast" ?
      latest - tenMinutesSeconds :
      latest - openWeatherRadarHistorySeconds;
    const globalForecastEnabled = globalForecastRadarEnabled();
    const max = mode === "futurecast" || globalForecastEnabled ?
      latest + sixHoursSeconds :
      latest;
    if (tm < min || tm > max) {
      throw new PublicHttpError(
        400,
        mode === "futurecast" ?
          "FutureCast supports precipitation forecast frames up to 6 hours." :
          "Global radar supports 2 hours of history and configured future frames.",
      );
    }
  } catch (error) {
    if (error instanceof PublicHttpError) {
      logger.warn("OpenWeather radar tile request rejected", {
        mode,
        code: error.safeCode,
      });
      sendTransparentRadarTile(response, "openweather_invalid_request");
      return;
    }
    throw error;
  }

  const cachedAuthFailure = upstreamAuthFailures.get("maps");
  if (
    cachedAuthFailure !== undefined &&
    cachedAuthFailure.expiresAtMs > Date.now()
  ) {
    sendTransparentRadarTile(response, cachedAuthFailure.error.safeCode);
    return;
  }

  const key = getOpenWeatherApiKey();
  const url = openWeatherRadarTileUrl(source, z, x, y, tm, key);

  let upstream: globalThis.Response;
  try {
    upstream = await fetchWithTimeout(url);
  } catch (error) {
    logger.warn("OpenWeather radar tile fetch failed", {
      mode,
      z,
      message: error instanceof Error ? error.message : "Unknown error",
    });
    sendTransparentRadarTile(response, "openweather_unavailable");
    return;
  }

  const contentType = upstream.headers.get("content-type");
  const bytes = Buffer.from(await upstream.arrayBuffer());
  const diagnostics = radarImageDiagnostics({
    source,
    z,
    x,
    y,
    frameTimestamp: tm,
    upstream,
    bytes,
  });

  if (!upstream.ok) {
    const upstreamErrorBody = bytes.toString("utf8", 0, 1000);
    const safeCode = safeUpstreamCode(upstream.status, upstreamErrorBody, "maps");
    logRadarTileDiagnostics("OpenWeather radar tile error", diagnostics, {
      code: safeCode,
    });
    if (upstream.status === 401 || upstream.status === 403) {
      upstreamAuthFailures.set("maps", {
        expiresAtMs: Date.now() + authFailureTtlMs,
        error: new PublicHttpError(
          upstreamStatus(upstream.status),
          safeUpstreamMessage(upstream.status, upstreamErrorBody, "maps"),
          safeCode,
        ),
      });
    }
    sendTransparentRadarTile(response, safeCode);
    return;
  }

  if (bytes.length === 0) {
    logRadarTileDiagnostics("OpenWeather radar tile returned empty image data", diagnostics);
    sendTransparentRadarTile(response, "openweather_tile_empty");
    return;
  }

  if (!diagnostics.isImage) {
    logRadarTileDiagnostics("OpenWeather radar tile returned non-image data", diagnostics);
    sendTransparentRadarTile(
      response,
      isSupportedRadarImageContentType(contentType ?? "") ?
        "openweather_tile_invalid_image" :
        "openweather_tile_invalid_content",
    );
    return;
  }

  logRadarTileDiagnostics("OpenWeather radar tile proxied", diagnostics);

  response
    .status(200)
    .set("Cache-Control", "public, max-age=120, stale-while-revalidate=120")
    .set("Content-Type", radarImageContentType(contentType, diagnostics))
    .send(bytes);
}

async function handleNoaaRadarTile(
  request: Request,
  response: Response,
  zRaw: string,
  xRaw: string,
  yRaw: string,
) {
  let z: number;
  let x: number;
  let y: number;
  let tm: number;

  try {
    z = parseInteger(zRaw, "z");
    x = parseInteger(xRaw, "x");
    y = parseInteger(yRaw, "y");

    if (z < 3 || z > 12) {
      throw new PublicHttpError(400, "NOAA radar zoom must be between 3 and 12.");
    }

    const maxTile = 2 ** z;
    if (x < 0 || y < 0 || x >= maxTile || y >= maxTile) {
      throw new PublicHttpError(400, "Radar tile coordinates are invalid.");
    }

    tm = parseRadarTileTime(request);
    const latest = Math.max(
      roundToNearestPastFiveMinuteUnix(),
      Math.floor(Date.now() / 1000) - fiveMinutesSeconds,
    );
    const min = latest - 4 * 60 * 60;
    if (tm < min || tm > latest + 15 * 60) {
      throw new PublicHttpError(
        400,
        "NOAA radar supports recent history only.",
      );
    }
  } catch (error) {
    if (error instanceof PublicHttpError) {
      logger.warn("NOAA radar tile request rejected", {
        source: "noaa_mrms",
        code: error.safeCode,
      });
      sendTransparentRadarTile(response, "noaa_invalid_request");
      return;
    }
    throw error;
  }

  const url = noaaRadarExportImageUrl(z, x, y, tm * 1000);
  let upstream: globalThis.Response;
  try {
    upstream = await fetchWithTimeout(url);
  } catch (error) {
    logger.warn("NOAA radar tile fetch failed", {
      source: "noaa_mrms",
      z,
      x,
      y,
      frameTimestamp: tm,
      message: error instanceof Error ? error.message : "Unknown error",
    });
    sendTransparentRadarTile(response, "noaa_unavailable");
    return;
  }

  const contentType = upstream.headers.get("content-type");
  const bytes = Buffer.from(await upstream.arrayBuffer());
  const diagnostics = radarImageDiagnostics({
    source: "noaa_mrms",
    z,
    x,
    y,
    frameTimestamp: tm,
    upstream,
    bytes,
  });

  if (!upstream.ok) {
    logRadarTileDiagnostics("NOAA radar tile error", diagnostics);
    sendTransparentRadarTile(response, safeNoaaTileErrorCode(upstream.status));
    return;
  }

  if (bytes.length === 0) {
    logRadarTileDiagnostics("NOAA radar tile returned empty image data", diagnostics);
    sendTransparentRadarTile(response, "noaa_tile_empty");
    return;
  }

  if (!diagnostics.isImage) {
    logRadarTileDiagnostics("NOAA radar tile returned non-image data", diagnostics);
    sendTransparentRadarTile(response, "noaa_tile_invalid_content");
    return;
  }

  logRadarTileDiagnostics("NOAA radar tile proxied", diagnostics);

  response
    .status(200)
    .set("Cache-Control", "public, max-age=120, stale-while-revalidate=120")
    .set("Content-Type", radarImageContentType(contentType, diagnostics))
    .send(bytes);
}

async function handleRadarHealth(request: Request, response: Response) {
  const lat = parseLatitude(requiredQuery(request, "lat"));
  const lon = parseLongitude(requiredQuery(request, "lon"));
  const source = queryParam(request, "source") === undefined ?
    radarSourceForMode(coordinateLooksUs(lat, lon) ? "us-forecast" : "global") :
    parseRadarSource(requiredQuery(request, "source"));
  const mode = radarModeForSource(source);
  const metadata = source === "noaa_mrms" ?
    await getNoaaRadarMetadata().catch((): NoaaRadarMetadata => {
      const latestFrameTimestamp = roundToNearestPastFiveMinuteUnix();
      return {
        latestFrameTimestamp,
        availableFrameCount: 0,
        availableFrom: latestFrameTimestamp - noaaRadarHistorySeconds,
        availableTo: latestFrameTimestamp,
        updateIntervalSeconds: fiveMinutesSeconds,
        availableTimestamps: [],
        diagnosticMessage:
          "NOAA metadata could not be loaded; rounded fallback was used.",
      };
    }) :
    {
      latestFrameTimestamp: roundToNearestPastTenMinuteUnix(),
      availableFrameCount: 0,
      availableFrom: roundToNearestPastTenMinuteUnix() -
        openWeatherRadarHistorySeconds,
      availableTo: roundToNearestPastTenMinuteUnix(),
      updateIntervalSeconds: tenMinutesSeconds,
      availableTimestamps: [],
      diagnosticMessage: null,
    };
  const explicitTime = queryParam(request, "time") ?? queryParam(request, "tm");
  const latestFrameTimestamp = explicitTime === undefined ?
    metadata.latestFrameTimestamp :
    parseInteger(explicitTime, "time");
  const probe = await probeRadarFrame({
    source,
    lat,
    lon,
    timestamp: latestFrameTimestamp,
  });
  if (probe.diagnostics !== null) {
    logRadarTileDiagnostics("Radar health probe completed", probe.diagnostics);
  }

  sendJson(response, 200, {
    source,
    mode,
    ok: probe.renderable,
    upstreamStatus: probe.diagnostics?.upstreamStatus ?? null,
    upstreamContentType: probe.diagnostics?.upstreamContentType ?? null,
    upstreamContentLength: probe.diagnostics?.upstreamContentLength ?? null,
    firstBytesHex: probe.diagnostics?.firstBytesHex ?? "",
    isImage: probe.diagnostics?.isImage ?? false,
    fallbackCode: probe.fallbackCode,
    humanReadableMessage: probe.humanReadableMessage ??
      (probe.renderable ?
        radarAvailableMessage(source) :
        "Radar source unavailable; base map still usable."),
    latestFrameTimestamp,
    availableFrameCount: metadata.availableFrameCount,
  }, "public, max-age=60");
}

function sendTransparentRadarTile(response: Response, errorCode: string) {
  response
    .status(200)
    .set("Cache-Control", radarFallbackCacheControl)
    .set("Content-Type", "image/png")
    .set("X-Grumpy-Skies-Tile-Fallback", errorCode)
    .send(transparentRadarTilePng);
}

async function openWeatherJson(
  pathname: string,
  params: Record<string, string | number | undefined>,
  routeLabel: string,
): Promise<unknown> {
  const authScope = providerAuthFailureScope(pathname);
  const cachedAuthFailure = upstreamAuthFailures.get(authScope);
  if (
    cachedAuthFailure !== undefined &&
    cachedAuthFailure.expiresAtMs > Date.now()
  ) {
    throw cachedAuthFailure.error;
  }

  const cacheKey = weatherCacheKey(pathname, params, routeLabel);
  const cached = jsonCache.get(cacheKey);
  if (cached !== undefined && cached.expiresAtMs > Date.now()) {
    return cached.value;
  }

  const pending = jsonInflight.get(cacheKey);
  if (pending !== undefined) {
    return pending;
  }

  const key = getOpenWeatherApiKey();
  const url = new URL(pathname, openWeatherApiBase);
  for (const [name, value] of Object.entries(params)) {
    if (value !== undefined) {
      url.searchParams.set(name, String(value));
    }
  }
  url.searchParams.set("appid", key);

  const request = fetchOpenWeatherJson(url, routeLabel, authScope);
  jsonInflight.set(cacheKey, request);
  try {
    const json = await request;
    jsonCache.set(cacheKey, {
      expiresAtMs: Date.now() + cacheTtlMs(routeLabel),
      value: json,
    });
    return json;
  } finally {
    jsonInflight.delete(cacheKey);
  }
}

async function fetchOpenWeatherJson(
  url: URL,
  routeLabel: string,
  authScope: string,
): Promise<unknown> {
  const maxAttempts = 2;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const upstream = await fetchWithTimeout(url);
    if (upstream.ok) {
      const json = await upstream.json();
      logger.info("OpenWeather API response", {
        route: routeLabel,
        status: upstream.status,
        dataLength: responseDataLength(json),
        timezone: responseTimezone(json),
      });
      return json;
    }

    const upstreamErrorBody = await safeUpstreamErrorBody(upstream);
    const safeCode = safeUpstreamCode(
      upstream.status,
      upstreamErrorBody,
      authScope,
    );
    logger.warn("OpenWeather API error", {
      route: routeLabel,
      status: upstream.status,
      code: safeCode,
    });

    if (shouldRetryUpstream(upstream.status) && attempt + 1 < maxAttempts) {
      await sleep(backoffDelayMs());
      continue;
    }

    const error = new PublicHttpError(
      upstreamStatus(upstream.status),
      safeUpstreamMessage(upstream.status, upstreamErrorBody, authScope),
      safeCode,
    );
    if (upstream.status === 401 || upstream.status === 403) {
      upstreamAuthFailures.set(authScope, {
        expiresAtMs: Date.now() + authFailureTtlMs,
        error,
      });
    }
    throw error;
  }

  throw new PublicHttpError(
    503,
    "Weather provider is temporarily unavailable.",
    "openweather_unavailable",
  );
}

function responseDataLength(raw: unknown): number | null {
  if (Array.isArray(raw)) {
    return raw.length;
  }
  const record = asRecord(raw);
  const candidates = [
    record.data,
    record.hourly,
    record.daily,
    record.minutely,
    record.list,
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate)) {
      return candidate.length;
    }
  }
  return null;
}

function responseTimezone(raw: unknown): string | null {
  const record = asRecord(raw);
  return stringOrNull(record.timezone);
}

async function fetchWithTimeout(url: URL): Promise<globalThis.Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), openWeatherTimeoutMs);
  try {
    return await fetch(url, {signal: controller.signal});
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") {
      throw new PublicHttpError(
        504,
        "Weather provider timed out. Try again soon.",
        "openweather_timeout",
      );
    }
    throw new PublicHttpError(
      503,
      "Weather provider is temporarily unavailable.",
      "openweather_unavailable",
    );
  } finally {
    clearTimeout(timeout);
  }
}

function radarSourceForMode(mode: RadarMode): RadarSource {
  if (mode === "us-forecast") return "noaa_mrms";
  if (mode === "futurecast") return "openweather_futurecast";
  return "openweather_global";
}

function radarModeForSource(source: RadarSource): RadarMode {
  if (source === "noaa_mrms") return "us-forecast";
  if (source === "openweather_futurecast") return "futurecast";
  return "global";
}

function noaaRadarExportImageUrl(
  z: number,
  x: number,
  y: number,
  epochMilliseconds: number,
): URL {
  const bbox = webMercatorTileBbox(z, x, y);
  const url = new URL(`${noaaRadarImageServerBase}/exportImage`);
  url.searchParams.set(
    "bbox",
    [bbox.xmin, bbox.ymin, bbox.xmax, bbox.ymax].join(","),
  );
  url.searchParams.set("bboxSR", "3857");
  url.searchParams.set("imageSR", "3857");
  url.searchParams.set("size", "256,256");
  url.searchParams.set("format", "png32");
  url.searchParams.set("transparent", "true");
  url.searchParams.set("time", String(epochMilliseconds));
  url.searchParams.set("f", "image");
  return url;
}

export function webMercatorTileBbox(
  z: number,
  x: number,
  y: number,
): WebMercatorBbox {
  const earthRadiusMeters = 6378137;
  const originShift = Math.PI * earthRadiusMeters;
  const tileSpan = (originShift * 2) / 2 ** z;
  const xmin = -originShift + x * tileSpan;
  const xmax = xmin + tileSpan;
  const ymax = originShift - y * tileSpan;
  const ymin = ymax - tileSpan;
  return {xmin, ymin, xmax, ymax};
}

function tileForLocation(
  latitude: number,
  longitude: number,
  zoom: number,
): {x: number; y: number} {
  const latRad = latitude * Math.PI / 180;
  const tileCount = 2 ** zoom;
  const x = Math.floor((longitude + 180) / 360 * tileCount);
  const y = Math.floor(
    (1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) /
      2 *
      tileCount,
  );
  return {
    x: Math.min(Math.max(x, 0), tileCount - 1),
    y: Math.min(Math.max(y, 0), tileCount - 1),
  };
}

async function getNoaaRadarMetadata(): Promise<NoaaRadarMetadata> {
  const metadataUrl = new URL(noaaRadarImageServerBase);
  metadataUrl.searchParams.set("f", "json");
  const upstream = await fetchWithTimeout(metadataUrl);
  if (!upstream.ok) {
    throw new PublicHttpError(
      upstreamStatus(upstream.status),
      "NOAA radar source unavailable; base map still usable.",
      safeNoaaTileErrorCode(upstream.status),
    );
  }

  const raw = asRecord(await upstream.json());
  const timeInfo = asRecord(raw.timeInfo);
  const extent = Array.isArray(timeInfo.timeExtent) ?
    timeInfo.timeExtent :
    [];
  const latestMs = numberOrNull(extent[1]);
  const startMs = numberOrNull(extent[0]);
  const extentLatestTimestamp = latestMs === null ?
    roundToNearestPastFiveMinuteUnix() :
    Math.floor(latestMs / 1000);
  const extentStartTimestamp = startMs === null ?
    extentLatestTimestamp - noaaRadarHistorySeconds :
    Math.floor(startMs / 1000);
  let diagnosticMessage: string | null = null;
  const availableTimestamps = await getNoaaAvailableRadarTimestamps()
    .catch((error): number[] => {
      diagnosticMessage =
        "NOAA available frame records could not be loaded.";
      logger.warn("NOAA radar available time query failed", {
        source: "noaa_mrms",
        message: error instanceof Error ? error.message : "Unknown error",
      });
      return [];
    });
  const clusteredTimestamps = clusterNoaaFrameTimestamps(availableTimestamps)
    .filter((timestamp) =>
      timestamp >= extentStartTimestamp && timestamp <= extentLatestTimestamp);
  const latestFrameTimestamp = clusteredTimestamps[0] ?? extentLatestTimestamp;
  const windowStart = Math.max(
    extentStartTimestamp,
    latestFrameTimestamp - noaaRadarHistorySeconds,
  );
  const windowTimestamps = clusteredTimestamps
    .filter((timestamp) => timestamp >= windowStart &&
      timestamp <= latestFrameTimestamp)
    .sort((left, right) => left - right);
  return {
    latestFrameTimestamp,
    availableFrameCount: windowTimestamps.length,
    availableFrom: windowTimestamps[0] ?? windowStart,
    availableTo: latestFrameTimestamp,
    updateIntervalSeconds: medianTimestampIntervalSeconds(windowTimestamps),
    availableTimestamps: windowTimestamps,
    diagnosticMessage,
  };
}

async function getNoaaAvailableRadarTimestamps(): Promise<number[]> {
  const url = new URL(`${noaaRadarImageServerBase}/query`);
  url.searchParams.set("f", "json");
  url.searchParams.set("where", "1=1");
  url.searchParams.set("outFields", "idp_validtime");
  url.searchParams.set("returnGeometry", "false");
  url.searchParams.set("returnDistinctValues", "true");
  url.searchParams.set("orderByFields", "idp_validtime desc");
  url.searchParams.set("resultRecordCount", String(noaaFrameQueryRecordCount));
  const upstream = await fetchWithTimeout(url);
  if (!upstream.ok) {
    throw new PublicHttpError(
      upstreamStatus(upstream.status),
      "NOAA radar source unavailable; base map still usable.",
      safeNoaaTileErrorCode(upstream.status),
    );
  }

  const raw = asRecord(await upstream.json());
  const features = Array.isArray(raw.features) ? raw.features : [];
  return features
    .map((feature) => {
      const attributes = asRecord(asRecord(feature).attributes);
      const validTimeMs = numberOrNull(attributes.idp_validtime);
      return validTimeMs === null ? null : Math.floor(validTimeMs / 1000);
    })
    .filter((timestamp): timestamp is number => timestamp !== null)
    .sort((left, right) => right - left);
}

function clusterNoaaFrameTimestamps(timestamps: number[]): number[] {
  const unique = [...new Set(timestamps)].sort((left, right) => right - left);
  const clustered: number[] = [];
  for (const timestamp of unique) {
    const currentClusterHead = clustered[clustered.length - 1];
    if (
      currentClusterHead === undefined ||
      currentClusterHead - timestamp > noaaFrameClusterSeconds
    ) {
      clustered.push(timestamp);
    }
  }
  return clustered;
}

function medianTimestampIntervalSeconds(timestamps: number[]): number | null {
  if (timestamps.length < 2) return null;
  const intervals: number[] = [];
  for (let index = 1; index < timestamps.length; index++) {
    intervals.push(timestamps[index] - timestamps[index - 1]);
  }
  intervals.sort((left, right) => left - right);
  return intervals[Math.floor(intervals.length / 2)];
}

async function buildValidatedRadarFrames({
  source,
  lat,
  lon,
  latest,
  timestamps,
  nowLabel,
}: {
  source: RadarSource;
  lat: number;
  lon: number;
  latest: number;
  timestamps: number[];
  nowLabel: string;
}): Promise<JsonRecord[]> {
  const frames = await mapWithConcurrency(timestamps, 4, async (timestamp) => {
    const probe = await probeRadarFrame({source, lat, lon, timestamp});
    return radarFrameRecord({source, timestamp, latest, nowLabel, probe});
  });
  for (const frame of frames) {
    logRadarFrameDiagnostics(frame);
  }
  return frames;
}

async function probeRadarFrame({
  source,
  lat,
  lon,
  timestamp,
}: {
  source: RadarSource;
  lat: number;
  lon: number;
  timestamp: number;
}): Promise<RadarFrameProbe> {
  const z = source === "openweather_global" ? 3 : 6;
  const tile = tileForLocation(lat, lon, z);
  let upstream: globalThis.Response;
  let bytes = Buffer.alloc(0);

  try {
    const url = radarProbeUrl(source, z, tile.x, tile.y, timestamp);
    upstream = await fetchWithTimeout(url);
    bytes = Buffer.from(await upstream.arrayBuffer());
  } catch (error) {
    return {
      source,
      frameTimestamp: timestamp,
      z,
      x: tile.x,
      y: tile.y,
      renderable: false,
      validImageResponses: 0,
      transparentFallbackTileResponses: 1,
      upstreamErrors: 1,
      fallbackCode: source === "noaa_mrms" ?
        noaaProbeFallbackCode(error) :
        openWeatherProbeFallbackCode(error),
      humanReadableMessage: source === "openweather_futurecast" ?
        "FutureCast requires OpenWeather precipitation forecast map access." :
        "Radar source unavailable; base map still usable.",
      diagnostics: null,
    };
  }

  const diagnostics = radarImageDiagnostics({
    source,
    z,
    x: tile.x,
    y: tile.y,
    frameTimestamp: timestamp,
    upstream,
    bytes,
  });
  const renderable = upstream.ok && diagnostics.isImage;
  return {
    source,
    frameTimestamp: timestamp,
    z,
    x: tile.x,
    y: tile.y,
    renderable,
    validImageResponses: renderable ? 1 : 0,
    transparentFallbackTileResponses: renderable ? 0 : 1,
    upstreamErrors: renderable ? 0 : 1,
    fallbackCode: renderable ?
      null :
      radarProbeFallbackCode(source, upstream, diagnostics, bytes),
    humanReadableMessage: renderable ?
      radarAvailableMessage(source) :
      "Radar source unavailable; base map still usable.",
    diagnostics,
  };
}

function radarProbeUrl(
  source: RadarSource,
  z: number,
  x: number,
  y: number,
  timestamp: number,
): URL {
  if (source === "noaa_mrms") {
    return noaaRadarExportImageUrl(z, x, y, timestamp * 1000);
  }
  return openWeatherRadarTileUrl(
    source,
    z,
    x,
    y,
    timestamp,
    getOpenWeatherApiKey(),
  );
}

export function openWeatherRadarTilePath(
  source: OpenWeatherRadarSource,
  z: number,
  x: number,
  y: number,
): string {
  const productPath = source === "openweather_futurecast" ?
    "radar/us/forecast" :
    "radar/forecast";
  return `/maps/2.0/${productPath}/${z}/${x}/${y}`;
}

function openWeatherRadarTileUrl(
  source: OpenWeatherRadarSource,
  z: number,
  x: number,
  y: number,
  timestamp: number,
  apiKey: string,
): URL {
  const tilePath = openWeatherRadarTilePath(source, z, x, y);
  const url = new URL(tilePath, openWeatherMapBase);
  url.searchParams.set("appid", apiKey);
  url.searchParams.set("tm", String(timestamp));
  return url;
}

function radarFrameRecord({
  source,
  timestamp,
  latest,
  nowLabel,
  probe,
}: {
  source: RadarSource;
  timestamp: number;
  latest: number;
  nowLabel: string;
  probe: RadarFrameProbe;
}): JsonRecord {
  const offsetSeconds = timestamp - latest;
  const isLatest = offsetSeconds === 0;
  const label = isLatest ? nowLabel : radarFrameOffsetLabel(offsetSeconds);
  const renderable = probe.renderable;
  return {
    source,
    timestamp,
    label,
    displayLabel: label,
    type: offsetSeconds < 0 ?
      "history" :
      offsetSeconds > 0 ? "forecast" : "latest",
    isLatest,
    renderable,
    fallbackCode: probe.fallbackCode,
    diagnosticMessage: probe.humanReadableMessage,
    diagnostics: {
      source,
      frameTimestamp: timestamp,
      displayLabel: label,
      tileRequests: 1,
      validImageResponses: probe.validImageResponses,
      transparentFallbackTileResponses:
        probe.transparentFallbackTileResponses,
      upstreamErrors: probe.upstreamErrors,
      renderable,
      skippedDuringPlayback: !renderable,
    },
  };
}

function logRadarFrameDiagnostics(frame: JsonRecord) {
  const diagnostics = asRecord(frame.diagnostics);
  logger.info("Radar frame diagnostics", {
    source: diagnostics.source,
    frameTimestamp: diagnostics.frameTimestamp,
    displayLabel: diagnostics.displayLabel,
    tileRequests: diagnostics.tileRequests,
    validImageResponses: diagnostics.validImageResponses,
    transparentFallbackTileResponses:
      diagnostics.transparentFallbackTileResponses,
    upstreamErrors: diagnostics.upstreamErrors,
    renderable: diagnostics.renderable,
    skippedDuringPlayback: diagnostics.skippedDuringPlayback,
  });
}

function radarProbeFallbackCode(
  source: RadarSource,
  upstream: globalThis.Response,
  diagnostics: RadarImageDiagnostics,
  bytes: Buffer,
): string {
  if (source === "noaa_mrms") {
    if (upstream.ok && !diagnostics.isImage) return "noaa_tile_invalid_content";
    return safeNoaaTileErrorCode(upstream.status);
  }
  if (upstream.ok && !diagnostics.isImage) {
    return isSupportedRadarImageContentType(
      diagnostics.upstreamContentType ?? "",
    ) || bytes.length > 0 ?
      "openweather_tile_invalid_image" :
      "openweather_tile_invalid_content";
  }
  return safeUpstreamCode(upstream.status, bytes.toString("utf8", 0, 1000), "maps");
}

function noaaProbeFallbackCode(error: unknown): string {
  if (error instanceof PublicHttpError && error.safeCode.includes("timeout")) {
    return "noaa_timeout";
  }
  if (error instanceof PublicHttpError && error.safeCode.includes("rate")) {
    return "noaa_rate_limited";
  }
  return "noaa_unavailable";
}

function openWeatherProbeFallbackCode(error: unknown): string {
  if (error instanceof PublicHttpError) return error.safeCode;
  return "openweather_unavailable";
}

function radarAvailableMessage(source: RadarSource): string {
  return source === "noaa_mrms" ?
    "NOAA MRMS radar is available." :
    "OpenWeather radar is available.";
}

function isOpenWeatherRadarAccessFailure(probe: RadarFrameProbe): boolean {
  return probe.fallbackCode === "openweather_radar_access_denied" ||
    probe.fallbackCode === "openweather_key_rejected" ||
    probe.fallbackCode === "OPENWEATHER_API_KEY_UNAVAILABLE" ||
    probe.fallbackCode === "OPENWEATHER_API_KEY_MISSING";
}

async function mapWithConcurrency<T, R>(
  items: T[],
  concurrency: number,
  mapper: (item: T) => Promise<R>,
): Promise<R[]> {
  const results: R[] = [];
  let nextIndex = 0;
  const workerCount = Math.min(concurrency, Math.max(items.length, 1));
  await Promise.all(Array.from({length: workerCount}, async () => {
    while (nextIndex < items.length) {
      const index = nextIndex;
      nextIndex++;
      results[index] = await mapper(items[index]);
    }
  }));
  return results;
}

function radarImageDiagnostics({
  source,
  z,
  x,
  y,
  frameTimestamp,
  upstream,
  bytes,
}: {
  source: RadarSource;
  z: number;
  x: number;
  y: number;
  frameTimestamp: number;
  upstream: globalThis.Response;
  bytes: Buffer;
}): RadarImageDiagnostics {
  const firstBytesHex = bytes.subarray(0, 8).toString("hex").toUpperCase();
  const isPng = bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4E &&
    bytes[3] === 0x47;
  const isJpeg = bytes.length >= 3 &&
    bytes[0] === 0xFF &&
    bytes[1] === 0xD8 &&
    bytes[2] === 0xFF;
  const contentLengthHeader = upstream.headers.get("content-length");
  const parsedContentLength = contentLengthHeader === null ?
    null :
    Number(contentLengthHeader);
  return {
    source,
    z,
    x,
    y,
    frameTimestamp,
    upstreamStatus: upstream.status,
    upstreamContentType: upstream.headers.get("content-type"),
    upstreamContentLength: Number.isFinite(parsedContentLength) ?
      parsedContentLength :
      bytes.length,
    firstBytesHex,
    isPng,
    isJpeg,
    isImage: isPng || isJpeg,
  };
}

function logRadarTileDiagnostics(
  message: string,
  diagnostics: RadarImageDiagnostics,
  extra: JsonRecord = {},
) {
  const payload = {
    source: diagnostics.source,
    z: diagnostics.z,
    x: diagnostics.x,
    y: diagnostics.y,
    frameTimestamp: diagnostics.frameTimestamp,
    upstreamStatus: diagnostics.upstreamStatus,
    upstreamContentType: diagnostics.upstreamContentType,
    upstreamContentLength: diagnostics.upstreamContentLength,
    firstBytesHex: diagnostics.firstBytesHex,
    isPng: diagnostics.isPng,
    isJpeg: diagnostics.isJpeg,
    isImage: diagnostics.isImage,
    ...extra,
  };
  if (diagnostics.isImage && diagnostics.upstreamStatus !== null &&
    diagnostics.upstreamStatus >= 200 && diagnostics.upstreamStatus < 300) {
    logger.info(message, payload);
    return;
  }
  logger.warn(message, payload);
}

function radarImageContentType(
  upstreamContentType: string | null,
  diagnostics: RadarImageDiagnostics,
): string {
  if (diagnostics.isPng) {
    return "image/png";
  }
  if (diagnostics.isJpeg) {
    return "image/jpeg";
  }
  return isSupportedRadarImageContentType(upstreamContentType ?? "") ?
    upstreamContentType ?? "image/png" :
    "image/png";
}

function safeNoaaTileErrorCode(status: number): string {
  if (status === 400 || status === 404) {
    return "noaa_invalid_request";
  }
  if (status === 429) {
    return "noaa_rate_limited";
  }
  if (status >= 500) {
    return "noaa_unavailable";
  }
  return "noaa_request_failed";
}

function providerAuthFailureScope(pathname: string): string {
  if (pathname.startsWith("/data/3.0/onecall")) {
    return "onecall";
  }
  if (pathname.startsWith("/data/4.0/onecall/")) {
    return "onecall";
  }
  if (pathname.startsWith("/geo/")) {
    return "geo";
  }
  if (pathname.startsWith("/maps/")) {
    return "maps";
  }
  return "openweather";
}

export function weatherCacheKey(
  pathname: string,
  params: Record<string, string | number | undefined>,
  routeLabel: string,
): string {
  const precision = coordinatePrecision(routeLabel);
  const entries = Object.entries(params)
    .filter((entry): entry is [string, string | number] =>
      entry[1] !== undefined)
    .map(([name, value]) => {
      if ((name === "lat" || name === "lon") && typeof value === "number") {
        return [name, value.toFixed(precision)] as const;
      }
      return [name, String(value).trim().toLowerCase()] as const;
    })
    .sort(([left], [right]) => left.localeCompare(right));
  const query = entries.map(([name, value]) => `${name}=${value}`).join("&");
  return `${routeLabel}:${pathname}:${query}`;
}

function coordinatePrecision(routeLabel: string): number {
  return routeLabel.includes("minute") || routeLabel.includes("radar") ?
    3 :
    2;
}

function cacheTtlMs(routeLabel: string): number {
  if (routeLabel.startsWith("location/")) {
    return 7 * 24 * 60 * 60 * 1000;
  }
  return tenMinutesSeconds * 1000;
}

function shouldRetryUpstream(status: number): boolean {
  return status === 429 || status >= 500;
}

function backoffDelayMs(): number {
  return 250 + Math.floor(Math.random() * 350);
}

function sleep(delayMs: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, delayMs);
  });
}

function normalizedApiPath(request: Request): string {
  const pathname = new URL(request.url, "https://local.invalid").pathname;
  const withoutApiPrefix = pathname.replace(/^\/api(?=\/|$)/, "");
  return withoutApiPrefix === "" ? "/" : withoutApiPrefix;
}

function getOpenWeatherApiKey(): string {
  let key = "";
  try {
    key = openWeatherApiKey.value();
  } catch (error) {
    logger.error("OpenWeather secret is unavailable to this function", {
      message: error instanceof Error ? error.message : "Unknown error",
    });
    throw new PublicHttpError(
      500,
      "OpenWeather API key is not available to the weather function. Provide OPENWEATHER_API_KEY in functions/.secret.local for the emulator or bind it to the deployed function.",
      "OPENWEATHER_API_KEY_UNAVAILABLE",
    );
  }

  if (!key) {
    throw new PublicHttpError(
      500,
      "OpenWeather API key is not configured on the server. Set OPENWEATHER_API_KEY in functions/.secret.local for the emulator or Firebase Secret Manager for deployed functions.",
      "OPENWEATHER_API_KEY_MISSING",
    );
  }
  return key;
}

function globalForecastRadarEnabled(): boolean {
  return enableGlobalForecastRadar.value().toLowerCase() === "true";
}

function isOneCallAccessDenied(error: unknown): boolean {
  return error instanceof PublicHttpError &&
    error.safeCode === "openweather_one_call_access_denied";
}

function isSupportedRadarImageContentType(contentType: string): boolean {
  const mime = contentType.split(";")[0].trim().toLowerCase();
  return mime === "image/png" ||
    mime === "image/jpeg" ||
    mime === "image/jpg" ||
    mime === "image/webp";
}

function handleRouteError(
  response: Response,
  path: string,
  error: unknown,
) {
  if (error instanceof PublicHttpError) {
    sendJson(response, error.status, {
      error: {
        code: error.safeCode,
        message: error.safeMessage,
      },
    });
    return;
  }

  logger.error("Weather route failed", {
    path,
    message: error instanceof Error ? error.message : "Unknown error",
  });
  sendJson(response, 500, {
    error: {
      code: "WEATHER_RUNTIME_ERROR",
      message: "Weather data is temporarily unavailable. Try again soon.",
    },
  });
}

function sendJson(
  response: Response,
  status: number,
  body: JsonRecord,
  cacheControl = "no-store",
) {
  response
    .status(status)
    .set("Cache-Control", cacheControl)
    .json(body);
}

function requiredQuery(request: Request, name: string): string {
  const value = queryParam(request, name);
  if (value === undefined || value.trim() === "") {
    throw new PublicHttpError(400, `Missing required query parameter: ${name}.`);
  }
  return value;
}

function queryParam(request: Request, name: string): string | undefined {
  const value = request.query[name];
  if (Array.isArray(value)) {
    const first = value[0];
    return first === undefined ? undefined : String(first);
  }
  if (value === undefined) {
    return undefined;
  }
  return String(value);
}

function parseLimit(value: string | undefined): number {
  if (value === undefined || value.trim() === "") {
    return 5;
  }
  const limit = parseInteger(value, "limit");
  return Math.min(Math.max(limit, 1), 5);
}

export function parseLatitude(value: string): number {
  const lat = parseNumber(value, "lat");
  if (lat < -90 || lat > 90) {
    throw new PublicHttpError(400, "Latitude must be between -90 and 90.");
  }
  return lat;
}

export function parseLongitude(value: string): number {
  const lon = parseNumber(value, "lon");
  if (lon < -180 || lon > 180) {
    throw new PublicHttpError(400, "Longitude must be between -180 and 180.");
  }
  return lon;
}

export function parseUnits(value: string | undefined): "imperial" | "metric" |
  "standard" {
  const units = value ?? "imperial";
  if (units !== "imperial" && units !== "metric" && units !== "standard") {
    throw new PublicHttpError(
      400,
      "Units must be imperial, metric, or standard.",
    );
  }
  return units;
}

function parseRadarProduct(value: string): RadarProduct {
  const normalized = value.trim().toLowerCase();
  if (normalized === "us" || normalized === "global") {
    return normalized;
  }
  throw new PublicHttpError(
    400,
    "Radar product must be us or global.",
    "openweather_invalid_request",
  );
}

function parseRadarFrameProduct(
  value: string,
  lat: number,
  lon: number,
): RadarProduct {
  const normalized = value.trim().toLowerCase();
  if (normalized === "auto") {
    return coordinateLooksUs(lat, lon) ? "us" : "global";
  }
  return parseRadarProduct(normalized);
}

function radarModeForProduct(product: RadarProduct): RadarMode {
  return product === "us" ? "us-forecast" : "global";
}

function parseRadarSource(value: string): RadarSource {
  const normalized = value.trim().toLowerCase();
  if (
    normalized === "noaa_mrms" ||
    normalized === "openweather_futurecast" ||
    normalized === "openweather_global"
  ) {
    return normalized;
  }
  throw new PublicHttpError(
    400,
    "Radar source must be noaa_mrms, openweather_futurecast, or openweather_global.",
    "radar_invalid_request",
  );
}

function parseRadarTileTime(request: Request): number {
  return parseInteger(
    queryParam(request, "time") ?? requiredQuery(request, "tm"),
    "time",
  );
}

function parseFutureHours(value: string | undefined): number {
  if (value === undefined || value.trim() === "") return 6;
  return Math.min(Math.max(parseInteger(value, "hours"), 1), 6);
}

function coordinateLooksUs(lat: number, lon: number): boolean {
  return lat >= 18 && lat <= 72 && lon >= -170 && lon <= -64;
}

function buildRadarFrames(
  latest: number,
  forecastAvailable: boolean,
  stepSeconds = tenMinutesSeconds,
  historySeconds = openWeatherRadarHistorySeconds,
  source: RadarSource = "openweather_global",
): JsonRecord[] {
  const frames: JsonRecord[] = [];
  const min = latest - historySeconds;
  const max = forecastAvailable ? latest + sixHoursSeconds : latest;
  for (let timestamp = min; timestamp <= max; timestamp += stepSeconds) {
    const offsetSeconds = timestamp - latest;
    frames.push({
      timestamp,
      label: offsetSeconds === 0 ? "Latest" : radarFrameOffsetLabel(
        offsetSeconds,
      ),
      type: offsetSeconds < 0 ?
        "history" :
        offsetSeconds > 0 ? "forecast" : "latest",
      isLatest: offsetSeconds === 0,
      source,
    });
  }
  return frames;
}

function radarFrameOffsetLabel(offsetSeconds: number): string {
  const prefix = offsetSeconds < 0 ? "-" : "+";
  const minutes = Math.floor(Math.abs(offsetSeconds) / 60);
  if (minutes < 60) {
    return `${prefix}${minutes} min`;
  }
  const hours = Math.floor(minutes / 60);
  const extraMinutes = minutes % 60;
  if (extraMinutes === 0) {
    return `${prefix}${hours}h`;
  }
  return `${prefix}${hours}h ${extraMinutes}m`;
}

function parseInteger(value: string, label: string): number {
  if (!/^\d+$/.test(value)) {
    throw new PublicHttpError(400, `${label} must be a non-negative integer.`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed)) {
    throw new PublicHttpError(400, `${label} is too large.`);
  }
  return parsed;
}

function parseNumber(value: string, label: string): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    throw new PublicHttpError(400, `${label} must be a number.`);
  }
  return parsed;
}

function normalizeLocation(
  raw: unknown,
  source: "device" | "city" | "zip",
  fallbackLat?: number,
  fallbackLon?: number,
): JsonRecord | null {
  const record = asRecord(raw);
  const lat = numberOrNull(record.lat) ?? fallbackLat;
  const lon = numberOrNull(record.lon) ?? fallbackLon;
  const country = stringOrNull(record.country);
  if (lat === undefined || lon === undefined) {
    return null;
  }

  const name = stringOrNull(record.name) ??
    stringOrNull(asRecord(record.local_names).en) ??
    "Selected location";
  const normalized: JsonRecord = {
    name,
    country: country ?? "US",
    lat,
    lon,
    source,
  };
  const state = stringOrNull(record.state);
  if (state !== null) {
    normalized.state = state;
  }
  return normalized;
}

export function normalizeCurrentWeather(
  raw: unknown,
  units: "imperial" | "metric" | "standard" = "imperial",
): JsonRecord {
  const root = asRecord(raw);
  const record = pickDataRecord(raw);
  const coord = asRecord(root.coord);
  const main = asRecord(record.main);
  const wind = asRecord(record.wind);
  const sys = asRecord(record.sys);
  const weather = pickWeather(record);
  const alerts = Array.isArray(record.alerts) ? record.alerts : root.alerts;
  const weatherId = numberOrNull(weather.id);
  const weatherMain = stringOrNull(weather.main);
  const weatherDescription = stringOrNull(weather.description);
  const weatherIcon = stringOrNull(weather.icon);
  const observedAt = numberOrNull(record.dt);

  return {
    latitude: numberOrNull(root.lat ?? record.lat ?? coord.lat),
    longitude: numberOrNull(root.lon ?? record.lon ?? coord.lon),
    timezone: stringOrNull(root.timezone ?? record.timezone),
    timezoneOffset: numberOrNull(
      root.timezone_offset ??
      root.timezoneOffset ??
      record.timezone_offset ??
      record.timezoneOffset ??
      (typeof root.timezone === "number" ? root.timezone : undefined),
    ),
    observedAt,
    sunrise: numberOrNull(record.sunrise ?? sys.sunrise),
    sunset: numberOrNull(record.sunset ?? sys.sunset),
    temp: numberOrNull(record.temp ?? record.temperature ?? main.temp),
    feelsLike: numberOrNull(
      record.feels_like ??
      record.feelsLike ??
      main.feels_like ??
      main.feelsLike,
    ),
    pressure: numberOrNull(record.pressure ?? main.pressure),
    humidity: numberOrNull(record.humidity ?? main.humidity),
    dewPoint: numberOrNull(record.dew_point ?? record.dewPoint),
    uvi: numberOrNull(record.uvi ?? record.uvIndex),
    clouds: numberOrNull(record.clouds),
    visibility: numberOrNull(record.visibility),
    windSpeed: numberOrNull(record.wind_speed ?? record.windSpeed ?? wind.speed),
    windGust: numberOrNull(record.wind_gust ?? record.windGust ?? wind.gust),
    windDeg: numberOrNull(record.wind_deg ?? record.windDeg ?? wind.deg),
    rain1h: numberOrNull(asRecord(record.rain)["1h"] ?? record.rain1h),
    snow1h: numberOrNull(asRecord(record.snow)["1h"] ?? record.snow1h),
    weatherId,
    weatherMain,
    weatherDescription,
    weatherIcon,
    weather: {
      id: weatherId,
      main: weatherMain,
      description: weatherDescription,
      icon: weatherIcon,
    },
    alertIds: normalizeAlertIds(alerts),
    sourceUpdatedAt: observedAt,
    fetchedAt: new Date().toISOString(),
    units,
    dt: observedAt,
  };
}

export function normalizeForecastWeather(
  raw: unknown,
  units: "imperial" | "metric" | "standard" = "imperial",
): JsonRecord {
  const root = asRecord(raw);
  const timezoneOffset = numberOrNull(
    root.timezone_offset ??
    root.timezoneOffset,
  );
  return {
    latitude: numberOrNull(root.lat),
    longitude: numberOrNull(root.lon),
    timezone: stringOrNull(root.timezone),
    timezoneOffset,
    current: normalizeCurrentWeather(raw, units),
    minutes: normalizeMinutePrecipitationRecords(root.minutely, units),
    hourly: normalizeHourlyForecastRecords(root.hourly),
    daily: normalizeDailyForecastRecords(root.daily, timezoneOffset),
    alerts: normalizeWeatherAlerts(root.alerts),
    units,
  };
}

export function normalizeOneCallTimelineForecast(
  currentRaw: unknown,
  hourlyRaw: unknown,
  dailyRaw: unknown,
  units: "imperial" | "metric" | "standard" = "imperial",
  forecastErrors: JsonRecord = {},
): JsonRecord {
  const current = normalizeCurrentWeather(currentRaw, units);
  const hourlyRoot = asRecord(hourlyRaw);
  const dailyRoot = asRecord(dailyRaw);
  const timezoneOffset = numberOrNull(
    hourlyRoot.timezone_offset ??
    hourlyRoot.timezoneOffset ??
    dailyRoot.timezone_offset ??
    dailyRoot.timezoneOffset ??
    current.timezoneOffset,
  );
  const timezone = stringOrNull(
    hourlyRoot.timezone ??
    dailyRoot.timezone ??
    current.timezone,
  );
  const hourly = normalizeHourlyForecastRecords(dataArray(hourlyRaw));
  const daily = normalizeDailyForecastRecords(dataArray(dailyRaw), timezoneOffset);

  return {
    latitude: numberOrNull(hourlyRoot.lat ?? dailyRoot.lat ?? current.latitude),
    longitude: numberOrNull(hourlyRoot.lon ?? dailyRoot.lon ?? current.longitude),
    timezone,
    timezoneOffset,
    current,
    minutes: [],
    hourly,
    daily,
    hourlyTimeline: normalizeTimelineEnvelope(hourlyRaw, hourly),
    dailyTimeline: normalizeTimelineEnvelope(dailyRaw, daily),
    forecastErrors,
    alerts: [],
    units,
  };
}

function normalizeTimelineEnvelope(
  raw: unknown,
  data: JsonRecord[],
): JsonRecord {
  const root = asRecord(raw);
  const timezoneOffset = numberOrNull(root.timezone_offset ?? root.timezoneOffset);
  return {
    latitude: numberOrNull(root.lat),
    longitude: numberOrNull(root.lon),
    timezone: stringOrNull(root.timezone),
    timezone_offset: timezoneOffset,
    timezoneOffset,
    data,
    next: sanitizeNext(root.next),
  };
}

function normalizeMinutePrecipitation(
  raw: unknown,
  units: "imperial" | "metric" | "standard",
): JsonRecord[] {
  return normalizeMinutePrecipitationRecords(dataArray(raw), units);
}

function normalizeMinutePrecipitationRecords(
  raw: unknown,
  units: "imperial" | "metric" | "standard",
): JsonRecord[] {
  const records = Array.isArray(raw) ? raw : [];
  return records.slice(0, 60).map((item) => {
    const record = asRecord(item);
    const precipitationMm = numberOrNull(
      record.precipitation ??
      record.precip ??
      record.rain ??
      record.rain1h,
    ) ?? 0;
    return {
      dt: numberOrNull(record.dt),
      precipitation: units === "imperial" ?
        precipitationMm / 25.4 :
        precipitationMm,
    };
  });
}

function normalizeTimeline(raw: unknown, limit: number): JsonRecord[] {
  return normalizeHourlyForecastRecords(dataArray(raw)).slice(0, limit);
}

function normalizeHourlyForecastRecords(raw: unknown): JsonRecord[] {
  const records = Array.isArray(raw) ? raw : [];
  return records.map((item) => {
    const record = asRecord(item);
    const weather = pickWeather(record);
    const weatherId = numberOrNull(weather.id);
    const weatherMain = stringOrNull(weather.main);
    const weatherDescription = stringOrNull(weather.description);
    const weatherIcon = stringOrNull(weather.icon);
    const pop = numberOrNull(
      record.pop ??
      record.precipitation_probability,
    );
    const rain1h = numberOrNull(asRecord(record.rain)["1h"] ?? record.rain1h);
    const snow1h = numberOrNull(asRecord(record.snow)["1h"] ?? record.snow1h);
    return {
      dt: numberOrNull(record.dt),
      temp: numberOrNull(record.temp ?? record.temperature),
      feelsLike: numberOrNull(record.feels_like ?? record.feelsLike),
      pressure: numberOrNull(record.pressure),
      humidity: numberOrNull(record.humidity),
      dewPoint: numberOrNull(record.dew_point ?? record.dewPoint),
      uvi: numberOrNull(record.uvi ?? record.uvIndex),
      clouds: numberOrNull(record.clouds),
      visibility: numberOrNull(record.visibility),
      precipitationProbability: pop,
      pop,
      precipitation: numberOrNull(
        record.precipitation ??
        record.rain1h ??
        rain1h ??
        snow1h ??
        asRecord(record.rain)["1h"] ??
        asRecord(record.snow)["1h"] ??
        record.rain ??
        record.snow,
      ) ?? 0,
      rain1h,
      snow1h,
      windSpeed: numberOrNull(record.wind_speed ?? record.windSpeed),
      windGust: numberOrNull(record.wind_gust ?? record.windGust),
      windDeg: numberOrNull(record.wind_deg ?? record.windDeg),
      weatherId,
      weatherMain,
      weatherDescription,
      weatherIcon,
      weather: {
        description: weatherDescription,
        icon: weatherIcon,
        id: weatherId,
        main: weatherMain,
      },
      alertIds: normalizeAlertIds(record.alerts),
    };
  });
}

function normalizeDailyForecastRecords(
  raw: unknown,
  timezoneOffset: number | null,
): JsonRecord[] {
  const records = Array.isArray(raw) ? raw : [];
  return records.map((item) => {
    const record = asRecord(item);
    const temp = asRecord(record.temp);
    const feelsLike = asRecord(record.feels_like ?? record.feelsLike);
    const weather = pickWeather(record);
    const dt = numberOrNull(record.dt);
    const weatherId = numberOrNull(weather.id);
    const weatherMain = stringOrNull(weather.main);
    const weatherDescription = stringOrNull(weather.description);
    const weatherIcon = stringOrNull(weather.icon);
    const pop = numberOrNull(
      record.pop ??
      record.precipitation_probability,
    );
    return {
      dt,
      date: localDateIso(dt, timezoneOffset),
      sunrise: numberOrNull(record.sunrise),
      sunset: numberOrNull(record.sunset),
      moonrise: numberOrNull(record.moonrise),
      moonset: numberOrNull(record.moonset),
      moonPhase: numberOrNull(record.moon_phase ?? record.moonPhase),
      temp: {
        day: numberOrNull(temp.day),
        min: numberOrNull(record.minTemp ?? record.min_temp ?? temp.min),
        max: numberOrNull(record.maxTemp ?? record.max_temp ?? temp.max),
        night: numberOrNull(temp.night),
        eve: numberOrNull(temp.eve),
        morn: numberOrNull(temp.morn),
      },
      feelsLike: {
        day: numberOrNull(feelsLike.day),
        night: numberOrNull(feelsLike.night),
        eve: numberOrNull(feelsLike.eve),
        morn: numberOrNull(feelsLike.morn),
      },
      minTemp: numberOrNull(record.minTemp ?? record.min_temp ?? temp.min),
      maxTemp: numberOrNull(record.maxTemp ?? record.max_temp ?? temp.max),
      pressure: numberOrNull(record.pressure),
      humidity: numberOrNull(record.humidity),
      dewPoint: numberOrNull(record.dew_point ?? record.dewPoint),
      precipitationProbability: pop,
      pop,
      precipitation: numberOrNull(record.rain ?? record.snow ?? 0) ?? 0,
      windSpeed: numberOrNull(record.wind_speed ?? record.windSpeed),
      windGust: numberOrNull(record.wind_gust ?? record.windGust),
      windDeg: numberOrNull(record.wind_deg ?? record.windDeg),
      clouds: numberOrNull(record.clouds),
      uvi: numberOrNull(record.uvi ?? record.uvIndex),
      condition: stringOrNull(
        weather.description ??
        weather.main ??
        record.summary,
      ),
      weatherId,
      weatherMain,
      weatherDescription,
      weatherIcon,
      weather: {
        description: weatherDescription,
        icon: weatherIcon,
        id: weatherId,
        main: weatherMain,
      },
      alertIds: normalizeAlertIds(record.alerts),
    };
  });
}

function normalizeWeatherAlerts(raw: unknown): JsonRecord[] {
  const records = Array.isArray(raw) ? raw : [];
  return records.map((item) => {
    const record = asRecord(item);
    return {
      senderName: stringOrNull(record.senderName ?? record.sender_name) ??
        "Weather authority",
      event: stringOrNull(record.event) ?? "Weather alert",
      start: numberOrNull(record.start),
      end: numberOrNull(record.end),
      description: stringOrNull(record.description) ?? "",
    };
  });
}

function localDateIso(
  unixSeconds: number | null,
  timezoneOffset: number | null,
): string | null {
  if (unixSeconds === null) {
    return null;
  }
  const offsetSeconds = timezoneOffset ?? 0;
  const local = new Date((unixSeconds + offsetSeconds) * 1000);
  const year = local.getUTCFullYear();
  const month = `${local.getUTCMonth() + 1}`.padStart(2, "0");
  const day = `${local.getUTCDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}T00:00:00.000`;
}

function pickDataRecord(raw: unknown): JsonRecord {
  const record = asRecord(raw);
  if (Array.isArray(record.data) && record.data.length > 0) {
    return asRecord(record.data[0]);
  }
  if (record.current !== undefined) {
    return asRecord(record.current);
  }
  return record;
}

function dataArray(raw: unknown): unknown[] {
  const record = asRecord(raw);
  if (Array.isArray(record.data)) {
    return record.data;
  }
  if (Array.isArray(record.list)) {
    return record.list;
  }
  if (Array.isArray(record.hourly)) {
    return record.hourly;
  }
  return [];
}

function pickWeather(record: JsonRecord): JsonRecord {
  if (Array.isArray(record.weather) && record.weather.length > 0) {
    return asRecord(record.weather[0]);
  }
  return asRecord(record.weather);
}

function normalizeAlertIds(alerts: unknown): string[] {
  if (!Array.isArray(alerts)) {
    return [];
  }
  return alerts
    .map((alert) => {
      if (typeof alert === "string") {
        return alert;
      }
      const record = asRecord(alert);
      return stringOrNull(record.id ?? record.alert_id ?? record.alertId);
    })
    .filter((value): value is string =>
      value !== null && /^[A-Za-z0-9_-]{1,120}$/.test(value));
}

function sanitizeNext(value: unknown): string | null {
  const raw = stringOrNull(value);
  if (raw === null) {
    return null;
  }
  try {
    const parsed = new URL(raw);
    parsed.searchParams.delete("appid");
    return parsed.toString();
  } catch {
    return raw.replace(/([?&]appid=)[^&]+/i, "$1REDACTED");
  }
}

async function safeUpstreamErrorBody(
  response: globalThis.Response,
): Promise<string> {
  try {
    return (await response.text()).slice(0, 1000);
  } catch {
    return "";
  }
}

export function safeUpstreamCode(
  status: number,
  body = "",
  scope = "openweather",
): string {
  if (status === 401 || status === 403) {
    const normalized = body.toLowerCase();
    if (
      normalized.includes("subscription") ||
      normalized.includes("one call") ||
      normalized.includes("plan")
    ) {
      if (scope === "maps") {
        return "openweather_radar_access_denied";
      }
      return "openweather_one_call_access_denied";
    }
    return "openweather_key_rejected";
  }
  if (status === 400) {
    return "openweather_invalid_request";
  }
  if (status === 404) {
    return "openweather_not_found";
  }
  if (status === 429) {
    return "openweather_rate_limited";
  }
  if (status >= 500) {
    return "openweather_unavailable";
  }
  return "openweather_request_failed";
}

export function safeUpstreamMessage(
  status: number,
  body = "",
  scope = "openweather",
): string {
  if (status === 401 || status === 403) {
    const code = safeUpstreamCode(status, body, scope);
    if (code === "openweather_radar_access_denied") {
      return "OpenWeather rejected the server key for radar maps. Enable OpenWeather Maps/radar access for OPENWEATHER_API_KEY, then redeploy functions.";
    }
    if (code === "openweather_one_call_access_denied") {
      return "OpenWeather rejected the server key for One Call API 4.0. Enable the One Call by Call subscription for OPENWEATHER_API_KEY, then redeploy functions.";
    }
    return "OpenWeather rejected the server key. Check OPENWEATHER_API_KEY and redeploy after secret changes.";
  }
  if (status === 400) {
    return "The weather request had invalid parameters.";
  }
  if (status === 429) {
    return "Weather provider rate limits are active. Try again shortly.";
  }
  if (status >= 500) {
    return "Weather provider is temporarily unavailable. Try again soon.";
  }
  if (status === 404) {
    return "Weather provider did not find data for that request.";
  }
  return "Weather provider could not complete that request.";
}

function upstreamStatus(status: number): number {
  if (status === 401 || status === 403) {
    return 502;
  }
  if (status === 400 || status === 404 || status === 429) {
    return status;
  }
  if (status >= 500) {
    return 502;
  }
  return 400;
}

function asRecord(value: unknown): JsonRecord {
  if (value !== null && typeof value === "object" && !Array.isArray(value)) {
    return value as JsonRecord;
  }
  return {};
}

function numberOrNull(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ?
    value.trim() :
    null;
}
