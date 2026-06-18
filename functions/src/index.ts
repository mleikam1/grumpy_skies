import {initializeApp} from "firebase-admin/app";
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";

initializeApp();

export const openWeatherApiKey = defineSecret("OPENWEATHER_API_KEY");

export const weatherBackendHealth = onRequest(
  {
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
