import { match } from "ts-pattern";
import { cfg } from "@/config";
import { Elm, type FromElm } from "@/Main.elm";

const node = document.getElementById("app");
const {
  ports: {
    interopToElm: { send },
    interopFromElm: { subscribe },
  },
} = Elm.Main.init({
  node,
  flags: {
    basePath: cfg.BASE_URL,
    llmSettings: {
      model: cfg.VITE_LLM_MODEL,
      apiKey: cfg.VITE_LLM_API_KEY,
      endpoint: cfg.VITE_LLM_ENDPOINT,
    },
  },
});

subscribe((m) =>
  match<FromElm>(m)
    .with({ tag: "LoadTours" }, () => {
      try {
        const data = JSON.parse(localStorage.getItem("tours") || "");
        send({ tag: "ToursLoaded", data });
      } catch (_) {
        send({ tag: "ToursLoaded", data: [] });
      }
    })
    .with({ tag: "LoadSettings" }, () => {
      try {
        const data = JSON.parse(localStorage.getItem("settings") || "null");
        send({ tag: "SettingsLoaded", data });
      } catch (_) {
        send({ tag: "SettingsLoaded", data: null });
      }
    })
    .with({ tag: "SaveTour" }, ({ data }) => {
      const tours = JSON.parse(localStorage.getItem("tours") || "[]");
      localStorage.setItem("tours", JSON.stringify([...tours, data]));
    })
    .with({ tag: "SaveSettings" }, ({ data }) => {
      localStorage.setItem("settings", JSON.stringify(data));
      send({ tag: "SettingsSaved" });
    })
    .exhaustive()
);
