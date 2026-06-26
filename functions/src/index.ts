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
const tenMinutesSeconds = 10 * 60;
const twoHoursSeconds = 120 * 60;
const fiveHoursSeconds = 5 * 60 * 60;
const weatherCacheControl = "public, max-age=300, stale-while-revalidate=300";
const radarFallbackCacheControl = "public, max-age=30";
const openWeatherTimeoutMs = 8000;
const authFailureTtlMs = 5 * 60 * 1000;
const transparentRadarTilePng = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=",
  "base64",
);

type RadarMode = "us-forecast" | "global";
type RadarProduct = "us" | "global";

type JsonRecord = Record<string, unknown>;
type CacheEntry = {
  expiresAtMs: number;
  value: unknown;
};
type ErrorCacheEntry = {
  expiresAtMs: number;
  error: PublicHttpError;
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

      const alertMatch = path.match(/^\/weather\/alert\/([A-Za-z0-9_-]+)$/);
      if (alertMatch) {
        await handleAlert(alertMatch[1], response);
        return;
      }

      const tileMatch = path.match(
        /^\/radar\/tile\/(us-forecast|global)\/(\d+)\/(\d+)\/(\d+)\.png$/,
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
  const latest = roundToNearestPastTenMinuteUnix();
  const forecastAvailable =
    mode === "us-forecast" || globalForecastRadarEnabled();

  // Fail with the same sanitized secret errors as tile/weather routes.
  getOpenWeatherApiKey();

  const frames = buildRadarFrames(latest, forecastAvailable);
  sendJson(response, 200, {
    product,
    mode,
    productLabel: mode === "us-forecast" ?
      "US forecast radar" :
      "Global precipitation radar",
    latestTimestamp: latest,
    minTimestamp: frames[0]?.timestamp ?? latest,
    maxTimestamp: frames[frames.length - 1]?.timestamp ?? latest,
    forecastAvailable,
    frames,
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

    tm = parseInteger(requiredQuery(request, "tm"), "tm");
    if (tm % tenMinutesSeconds !== 0) {
      throw new PublicHttpError(
        400,
        "Radar time must be snapped to a 10-minute UTC step.",
      );
    }

    const latest = roundToNearestPastTenMinuteUnix();
    const min = latest - twoHoursSeconds;
    const globalForecastEnabled = globalForecastRadarEnabled();
    const max = mode === "us-forecast" || globalForecastEnabled ?
      latest + fiveHoursSeconds :
      latest;
    if (tm < min || tm > max) {
      throw new PublicHttpError(
        400,
        mode === "us-forecast" ?
          "US forecast radar supports 2 hours of history and 5 hours ahead." :
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
  const tilePath = mode === "us-forecast" ?
    `/maps/2.0/radar/us/forecast/${z}/${x}/${y}` :
    `/maps/2.0/radar/forecast/${z}/${x}/${y}`;
  const url = new URL(tilePath, openWeatherMapBase);
  url.searchParams.set("appid", key);
  url.searchParams.set("tm", String(tm));

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

  if (!upstream.ok) {
    const upstreamErrorBody = await safeUpstreamErrorBody(upstream);
    const safeCode = safeUpstreamCode(upstream.status, upstreamErrorBody, "maps");
    logger.warn("OpenWeather radar tile error", {
      status: upstream.status,
      code: safeCode,
      mode,
      z,
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

  logger.info("OpenWeather radar tile proxied", {
    status: upstream.status,
    mode,
    z,
    tm,
  });

  const contentType = upstream.headers.get("content-type") ?? "image/png";
  if (!isSupportedRadarImageContentType(contentType)) {
    logger.warn("OpenWeather radar tile returned non-image data", {
      contentType,
      mode,
      z,
    });
    sendTransparentRadarTile(response, "openweather_tile_invalid_content");
    return;
  }

  const bytes = Buffer.from(await upstream.arrayBuffer());
  if (bytes.length === 0) {
    logger.warn("OpenWeather radar tile returned empty image data", {
      contentType,
      mode,
      z,
    });
    sendTransparentRadarTile(response, "openweather_tile_empty");
    return;
  }

  response
    .status(200)
    .set("Cache-Control", "public, max-age=120, stale-while-revalidate=120")
    .set("Content-Type", contentType)
    .send(bytes);
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
      return upstream.json();
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

function providerAuthFailureScope(pathname: string): string {
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

function coordinateLooksUs(lat: number, lon: number): boolean {
  return lat >= 18 && lat <= 72 && lon >= -170 && lon <= -64;
}

function buildRadarFrames(
  latest: number,
  forecastAvailable: boolean,
): JsonRecord[] {
  const frames: JsonRecord[] = [];
  const min = latest - twoHoursSeconds;
  const max = forecastAvailable ? latest + fiveHoursSeconds : latest;
  for (let timestamp = min; timestamp <= max; timestamp += tenMinutesSeconds) {
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

function normalizeMinutePrecipitation(
  raw: unknown,
  units: "imperial" | "metric" | "standard",
): JsonRecord[] {
  const records = dataArray(raw);
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
  return dataArray(raw).slice(0, limit).map((item) => {
    const record = asRecord(item);
    const weather = pickWeather(record);
    return {
      dt: numberOrNull(record.dt),
      temp: numberOrNull(record.temp ?? record.temperature),
      feelsLike: numberOrNull(record.feels_like ?? record.feelsLike),
      humidity: numberOrNull(record.humidity),
      precipitationProbability: numberOrNull(
        record.pop ??
        record.precipitation_probability,
      ),
      precipitation: numberOrNull(
        record.precipitation ??
        record.rain ??
        record.rain1h ??
        asRecord(record.rain)["1h"],
      ) ?? 0,
      windSpeed: numberOrNull(record.wind_speed ?? record.windSpeed),
      windDeg: numberOrNull(record.wind_deg ?? record.windDeg),
      weather: {
        description: stringOrNull(weather.description),
        icon: stringOrNull(weather.icon),
        id: numberOrNull(weather.id),
      },
      alertIds: normalizeAlertIds(record.alerts),
    };
  });
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
