---
applyTo: "**/*.elm"
---

# Elm Guidelines

- Follow the best practice rules available in this document
- Each rule has two code examples:
  - Bad: Avoid writting code in this way
  - Good: Always try to use the good patterns where they apply

## TypeScript Interop

CRITICAL:
Never use TypeScript for application logic! Always prefer Elm code over TypeScript.

CRITICAL:
Always run `bun interop` after modifying `InteropDefinitions.elm` to get up-to-date type definitions.

Read `@src/InteropDefinitions.elm` first, when trying to interop with TypeScript.

- Add variants to `ToElm` and `FromElm` types in order to add new features.
- Create codecs for the new types.
- Run `bun interop` in order to generate the new Typescript definitions.
- Handle new variants in Elm's `subscription` function.
- Handle new variants in `@src/main.ts` at the `subcribe(msg => ...)` function call.
- This makes working in TypeScript very similar as handling messages in Elm.

## Routing

- Use `@src/Routes.elm` to add new routes.
- Handle new route variants for the `Route` type in `@src/Main.elm`

## Avoid Type Blindness

Type blindness is when you have several values of the same type that could get mixed up.

```elm
-- Bad: A Float could by any other currency
priceInEuros : Float
priceInEuros = 1

-- Good: Wrap the Float inside a custom type
type Euro = Euro Float
priceInEuros : Euro
priceInEuro =
  Euro 2.0
```

## Unwrap `Maybe` and `Result` early

Unwrap `Maybe`, `Result` or `RemoteData` as early as possible.

```elm
-- Bad: Maybe extends throught the codebase like a virus
userCard : Maybe User -> Html Msg
userCard maybeUser =
   div [] [ userInfo maybeUser ]

-- Good: We remove uncertainty at the edges of our program
userCard : Maybe User -> Html Msg
userCard maybeUser =
    case maybeUser of
        Nothing ->
            div [] [ text "No user" ]

        Just user ->
            div [] [ userInfo user ]
```

## Wrap Custom Types early

Wrap custom types early, ie: just after fetching data from external sources.
Then try to unwrap as late as possible, enforcing the types throughout the code.

```elm
-- Bad: This function could take any Float, not just Dollars
displayPriceInDollars : Float -> String
displayPriceInDollars price =
    "USD$" ++ String.fromFloat price

-- Good: Unwrap late to enforce the type to the view
type Dollar = Dollar Float
displayPriceInDollars : Dollar -> String
displayPriceInDollars (Dollar price) =
    "USD$" ++ String.fromFloat price
```

## Avoid impossible states

Favor the use of custom types that precisely model the environment.

```elm
-- Bad: Data can't be present and loading at the same time
type alias Model =
    { isLoading: Bool
    , data: Maybe Data
    }

-- Good: Data can be either loading or loaded
type RemoteData
    = Loading
    | Loaded Data
    | Failed Http.Error

type alias Model =
    { data : RemoteData }
```

## Minimize `Bool` usage

Boolean ambiguity can lead to loss of intent and loss of information in our code.

```elm
-- Bad: What does `True` means here?
bookFlight : String -> Bool -> Flight

-- Good: the function intention is very clear now
bookFlight: Airport -> Category -> Flight
bookFlight LAX Premium
```

## Named arguments

Sometimes the order of arguments can be ambiguous, use a record in such cases:

```elm
-- Bad: We don't know initial and end dates here
bookRoom: Date -> Date -> Room

-- Good: We know exactly how to pass arguments to this function
bookRoom { from: Date, until: Date } -> Room
```

## Use The Compiler To Your Advantage

Elm is known for its sound and friendly compiler, use it as your superpower:

```elm
type Color
    = Red
    | Yellow
    | Green
    | Blue -- Recently added

-- Bad: We don't get compiler help when we forget to add the new color
all : List Color
all =
    -- Forgot to add Blue here
    [ Red, Yellow, Green ]

-- Good: Blue is still missing, but now, the compiler will show us an error
all : List Color
all =
    next [] |> List.reverse

next : List Color -> List Color
next list =
    case List.head list of
        Nothing ->
            Red :: list |> next

        Just Red ->
            Yellow :: list |> next

        Just Yellow ->
            Green :: list |> next

        Just Green ->
            list -- return the list as is on the final variant
```

Avoid pattern matching with wildcards, instead, use the compiler's exhaustive checking

```elm
type Color
    = Red
    | Green
    | Yellow -- Recently added

-- Bad: The compiler won't tell us there's a missing path here
canCrossStreet : Color -> Boolean
canCrossStreet color =
    case color of
        Green -> True
        _ -> False

-- Good: Now the compiler will show an error about the missing path
canCrossStreet : Color -> Boolean
canCrossStreet color =
    case color of
        Green -> True
        Red -> False -- Good: Yellow is still missing, but now, the compiler will show us an error
```
