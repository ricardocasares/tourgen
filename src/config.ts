import { z } from "zod";

const config = z.object({
  BASE_URL: z.string().default("/"),
  VITE_LLM_MODEL: z.string().default("qwen2.5-coder:7b"),
  VITE_LLM_API_KEY: z.string().default(""),
  VITE_LLM_ENDPOINT: z.url().default("https://tourgen.loca.lt"),
});

export const cfg = config.parse(import.meta.env);
