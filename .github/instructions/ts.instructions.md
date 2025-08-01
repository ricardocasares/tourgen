---
applyTo: "**/*.ts"
---

## TypeScript instructions

CRITICAL:
Never use TypeScript for application logic! Always prefer Elm code over TypeScript.

Whenever you have to use TypeScript, follow these guidelines:

- Prefer Elm over TypeScript!
- Never modify `tsconfig.json`!
- Favor functional programming style
- Favor the use of Sum types over Product types
- Favor short, concise and single value returning functions
- Use `ts-pattern` match to match on messages and handle errors
- Avoid using booleans in records or anything other than boolean logic
- Always use absolute paths using `@/` prefix
