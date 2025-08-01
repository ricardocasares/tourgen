# Copilot Instructions

This codebase uses Elm, a pure functional language.

## General Guidelines

- Keep your responses short and concise
- Vite dependency is already installed and configured
- Run `bun interop` to generate types for typescript interop
- Run `bun dev` to get a working http server
- Run `bun compile` to check for Elm compiler errors
- Run `bun lint` for linting Elm files and fix errors
- Run `bun run test` for testing your changes
- Use Elm v0.19.1 when generating Elm code
- Minimize usage of external dependencies
- Check the #problems tab to resolve issues
- Create small reusable functions
- Keep the `update` function clean and readable
- Keep indentation low by using Elm's pipeline operator `|>`

## Commit messages

- Keep commit messages short and concise
- Choose one of the following prefixes:
  - ai: for changes made to copilot instructions
  - ui: for cosmetic changes only
  - ci: for changes made to github workflows
  - doc: for README.md updates or code comments
  - dep: for changes in dependencies
  - fix: for code fixes
  - feat: for new features implemented in the code

## Writing new Features

- Create a new rfc inside `./rfc` folder
- Name files using the pattern: `00X-feature-name-xxx.md`
- Give a general overview of the feature
- Include the following mandatory sections:
  - Model changes
  - Message changes
  - Routing changes
  - Changes to the `update` function
  - Interop messages
