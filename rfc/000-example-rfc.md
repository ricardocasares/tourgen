# Example RFC

This is just a placeholder

## Model Changes

```elm
type alias Model =
    { -- New Model Records
    , count : Int
    }
```

## Message Changes

```elm
type Msg
    =
    -- New Message Variants
    | Increment
    | Decrement
    | Reset
```

## Routing Changes

```elm
type Route
    = Home
    -- New Route Variants
    | Counter
```

## Update Function Changes

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- Previous Message Handlers
        -- New Message Handlers
        Reset ->
            (
                model | counter = 0,
                Cmd.none
            )
        Increment ->
            (
                model | counter = model.counter + 1,
                Cmd.none
            )
        Decrement ->
            (
                model | counter = model.counter - 1,
                Cmd.none
            )
```

## Interop messages

```elm
type FromElm
    = SaveCount Int
```

```typescript
import { match } from "ts-pattern";
import { Elm, type FromElm } from "@/Main.elm";

const app = Elm.Main.init({
  node: document.getElementById("app"),
});

app.ports.interopFromElm.subcribe((msg) =>
  match<FromElm>(msg)
    // previous handlers
    .with({ tag: "SaveCount" }, ({ count }) => saveCount(count))
    .exhaustive()
);

function saveCount(n) {
  localStorage.setItem("count", n);
  return app.ports.interopToElm.send({ tag: "CountSaved" });
}
```
