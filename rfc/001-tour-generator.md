# LLM Tour Generator

## RFC Prompt

The application displays an input box where the user writes a prompt asking for a walking tour for a given city, example:

- A two hour walking tour around Kraków, Poland. Include museums, historical landmarks and a place with good food.
- A city tour around Prage historic centre. Take me through traditional Czech brewed beer bars.

When the user submits the prompt, a call to an LLM is made to request the tour generation.

### Layout elements

- A navigation bar the following links:
  - Home
  - Tours

### Settings page

#### Elements

- Input box for the LLM endpoint
- Input box for the LLM model
- Input box for the LLM API key
- Default endpoint is: `http://localhost:11434`
- Default model is `qwen3:8b`
- Default api key is an empty string

Default values are configurable via Elm flags, which are taken from environment variables using vite's `import.meta.env`

#### Behaviours

- LLM endpoint, model and API key are configurable
- Create a Settings route where the user can configure those settings

### Home page

#### Elements

- A centered input box to type the prompt
- A submit button to generate the tour
- A list of recently generated tours

#### Behaviours

- User can generate a tour
- When generated successfully, redirect to the tour page
- When generation errored, the user sees an error description and tries again
- User can click on an already generated tour and navigates to that tour's page

### Tour page

### Elements

- The tour main description
- A list of the tour stop titles inside an accordeon to expand the description
- The first stop is expanded by default

#### Behaviours

- User can click a toggle button to expand and contract each of the tour stop descriptions

## Model Changes

```elm
type alias LLMSettings =
    { endpoint : String
    , model : String
    , apiKey : String
    }

type alias LLMResponse =
    { response : String
    }

type alias Coordinates =
    { latitude : Float
    , longitude : Float
    }

type TourStop =
    { title : String
    , description : String
    , coordinates : Coordinates
    , expanded : Bool
    }

type Tour =
    { id : String
    , prompt : String
    , description : String
    , coordinates : Coordinates
    , stops : List TourStop
    }

type GenerationStatus
    = Idle
    | Generating
    | Success Tour
    | Failed String

type alias Model =
    { prompt : String
    , generationStatus : GenerationStatus
    , tours : List Tour
    , settings : LLMSettings
    , key : Nav.Key
    , url : Url.Url
    , route : Route
    }
```

## Message Changes

```elm
type Msg
    = NoOp
    | JSReady
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url

    -- Navigation
    | NavigateToHome
    | NavigateToTours
    | NavigateToSettings
    | NavigateToTour String

    -- Home Page
    | UpdatePrompt String
    | GenerateTour
    | LLMResponseReceived (Result Http.Error LLMResponse)
    | ToursLoaded (List Tour)

    -- Tour Page
    | ToggleTourStop Int

    -- Settings Page
    | UpdateEndpoint String
    | UpdateModel String
    | UpdateApiKey String
    | SaveSettings
    | SettingsSaved
```

## Routing Changes

```elm
type Route
    = Home
    | Tours
    | Tour String
    | Settings
    | NotFound
```

## Update Function Changes

```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        JSReady ->
            ( model, IO.fromElm IO.LoadTours )

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url, route = Routes.fromUrl url }, Cmd.none )

        -- Navigation
        NavigateToHome ->
            ( model, Nav.pushUrl model.key "/" )

        NavigateToTours ->
            ( model, Nav.pushUrl model.key "/tours" )

        NavigateToSettings ->
            ( model, Nav.pushUrl model.key "/settings" )

        NavigateToTour id ->
            ( model, Nav.pushUrl model.key ("/tour/" ++ id) )

        -- Home Page
        UpdatePrompt value ->
            ( { model | prompt = value }, Cmd.none )

        GenerateTour ->
            ( { model | generationStatus = Generating }
            , generateTourRequest model.settings model.prompt
            )

        LLMResponseReceived result ->
            case result of
                Ok response ->
                    case decodeResponse response.response of
                        Ok tourData ->
                            let
                                -- Process tour data and add expanded property to the first stop
                                stopsWithExpanded =
                                    List.indexedMap
                                        (\i stopData ->
                                            { title = stopData.title
                                            , description = stopData.description
                                            , coordinates = stopData.coordinates
                                            , expanded = i == 0
                                            }
                                        )
                                        tourData.stops

                                tour =
                                    { id = tourData.id
                                    , prompt = model.prompt
                                    , description = tourData.description
                                    , coordinates = tourData.coordinates
                                    , stops = stopsWithExpanded
                                    }
                            in
                            ( { model
                              | generationStatus = Success tour
                              , tours = tour :: model.tours
                              }
                            , Cmd.batch
                                [ Nav.pushUrl model.key ("/tour/" ++ tour.id)
                                , IO.fromElm (IO.SaveTour tour)
                                ]
                            )

                        Err err ->
                            ( { model | generationStatus = Failed ("Failed to parse LLM response: " ++ err) }
                            , Cmd.none
                            )

                Err httpError ->
                    ( { model | generationStatus = Failed (httpErrorToString httpError) }
                    , Cmd.none
                    )

        -- Tour Page
        ToggleTourStop index ->
            case model.route of
                Tour id ->
                    let
                        updateTour tour =
                            if tour.id == id then
                                let
                                    newStops =
                                        List.indexedMap
                                            (\i stop ->
                                                if i == index then
                                                    { stop | expanded = not stop.expanded }
                                                else
                                                    stop
                                            )
                                            tour.stops
                                in
                                { tour | stops = newStops }
                            else
                                tour

                        newTours =
                            List.map updateTour model.tours
                    in
                    ( { model | tours = newTours }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ToursLoaded tours ->
            ( { model | tours = tours }, Cmd.none )

        -- Settings Page
        UpdateEndpoint value ->
            let
                settings =
                    model.settings

                newSettings =
                    { settings | endpoint = value }
            in
            ( { model | settings = newSettings }, Cmd.none )

        UpdateModel value ->
            let
                settings =
                    model.settings

                newSettings =
                    { settings | model = value }
            in
            ( { model | settings = newSettings }, Cmd.none )

        UpdateApiKey value ->
            let
                settings =
                    model.settings

                newSettings =
                    { settings | apiKey = value }
            in
            ( { model | settings = newSettings }, Cmd.none )

        SaveSettings ->
            ( model
            , IO.fromElm (IO.SaveSettings model.settings)
            )

        SettingsSaved ->
            ( model, Cmd.none )

-- Helper functions for LLM

generateTourRequest : LLMSettings -> String -> Cmd Msg
generateTourRequest settings prompt =
    Http.post
        { url = settings.endpoint ++ "/api/generate"
        , body = Http.jsonBody (generateRequestBody settings.model prompt)
        , expect = Http.expectJson LLMResponseReceived llmResponseDecoder
        }

generateRequestBody : String -> String -> Json.Encode.Value
generateRequestBody model prompt =
    Json.Encode.object
        [ ( "model", Json.Encode.string model )
        , ( "prompt", Json.Encode.string (createPromptTemplate prompt) )
        ]

createPromptTemplate : String -> String
createPromptTemplate prompt =
    "Create a walking tour based on this prompt: \"" ++ prompt ++ "\". " ++
    "Respond with a JSON object containing: " ++
    "- id: a unique string id " ++
    "- description: a general description of the tour " ++
    "- coordinates: an object with latitude and longitude of the main city or area (REQUIRED) " ++
    "- stops: an array of stops, each with: " ++
    "  - title: a short title for the stop " ++
    "  - description: a detailed description of the stop " ++
    "  - coordinates: an object with latitude and longitude of this specific stop (REQUIRED)"

-- Decoders for LLM response

llmResponseDecoder : Json.Decode.Decoder LLMResponse
llmResponseDecoder =
    Json.Decode.map LLMResponse
        (Json.Decode.field "response" Json.Decode.string)

decodeResponse : String -> Result String TourData
decodeResponse jsonStr =
    Json.Decode.decodeString tourDataDecoder jsonStr
        |> Result.mapError Json.Decode.errorToString

type alias TourData =
    { id : String
    , description : String
    , coordinates : Coordinates
    , stops : List TourStopData
    }

type alias TourStopData =
    { title : String
    , description : String
    , coordinates : Coordinates
    }

tourDataDecoder : Json.Decode.Decoder TourData
tourDataDecoder =
    Json.Decode.map4 TourData
        (Json.Decode.field "id" Json.Decode.string)
        (Json.Decode.field "description" Json.Decode.string)
        (Json.Decode.field "coordinates" coordinatesDecoder)
        (Json.Decode.field "stops" (Json.Decode.list tourStopDataDecoder))

tourStopDataDecoder : Json.Decode.Decoder TourStopData
tourStopDataDecoder =
    Json.Decode.map3 TourStopData
        (Json.Decode.field "title" Json.Decode.string)
        (Json.Decode.field "description" Json.Decode.string)
        (Json.Decode.field "coordinates" coordinatesDecoder)

coordinatesDecoder : Json.Decode.Decoder Coordinates
coordinatesDecoder =
    Json.Decode.map2 Coordinates
        (Json.Decode.field "latitude" Json.Decode.float)
        (Json.Decode.field "longitude" Json.Decode.float)

httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody message ->
            "Bad body: " ++ message
```

## Interop messages

```elm
type alias LLMSettings =
    { endpoint : String
    , model : String
    , apiKey : String
    }

type FromElm
    = SaveSettings LLMSettings
    | SaveTour Tour
    | LoadTours

type ToElm
    = SettingsSaved
    | ToursLoaded (List Tour)
```

```typescript
import { match } from "ts-pattern";
import { Elm, type FromElm, type Tour } from "@/Main.elm";

// Read environment variables with default values
const defaultEndpoint =
  import.meta.env.VITE_LLM_ENDPOINT || "http://localhost:11434";
const defaultModel = import.meta.env.VITE_LLM_MODEL || "qwen3:8b";
const defaultApiKey = import.meta.env.VITE_LLM_API_KEY || "";

const app = Elm.Main.init({
  node: document.getElementById("app"),
  flags: {
    basePath: import.meta.env.BASE_URL || "/",
    llmSettings: {
      endpoint: defaultEndpoint,
      model: defaultModel,
      apiKey: defaultApiKey,
    },
  },
});

app.ports.interopFromElm.subscribe((msg) =>
  match<FromElm>(msg)
    .with({ tag: "ElmReady" }, () => {
      app.ports.interopToElm.send({ tag: "JSReady" });
    })
    .with({ tag: "SaveSettings" }, (settings) => {
      localStorage.setItem("llmSettings", JSON.stringify(settings));
      app.ports.interopToElm.send({ tag: "SettingsSaved" });
    })
    .with({ tag: "SaveTour" }, (tour) => {
      // Get existing tours from localStorage
      const toursJson = localStorage.getItem("tours") || "[]";
      let tours: Tour[] = [];

      try {
        tours = JSON.parse(toursJson);
      } catch (e) {
        console.error("Failed to parse tours from localStorage");
      }

      // Add new tour to the beginning of the list
      tours = [tour, ...tours];

      // Save back to localStorage
      localStorage.setItem("tours", JSON.stringify(tours));
    })
    .with({ tag: "LoadTours" }, () => {
      // Load tours from localStorage
      const toursJson = localStorage.getItem("tours") || "[]";
      let tours: Tour[] = [];

      try {
        tours = JSON.parse(toursJson);
      } catch (e) {
        console.error("Failed to parse tours from localStorage");
      }

      app.ports.interopToElm.send({
        tag: "ToursLoaded",
        tours: tours,
      });
    })
    .exhaustive()
);
```
