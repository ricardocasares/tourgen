module Main exposing (Coordinates, GenerationStatus, LLMResponse, LLMSettings, Model, Msg(..), Tour, TourStop, main)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, a, button, div, form, h1, h2, h3, input, label, li, p, span, text, ul)
import Html.Attributes exposing (attribute, class, disabled, href, placeholder, type_, value)
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import InteropDefinitions as IO
import InteropPorts as IO
import Json.Decode
import Json.Encode
import Routes exposing (Route(..))
import Url


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


type alias TourStop =
    { title : String
    , description : String
    , coordinates : Coordinates
    , expanded : Bool
    }


type alias Tour =
    { id : String
    , title : String
    , description : String
    , coordinates : Coordinates
    , stops : List TourStop
    }


type GenerationStatus
    = Idle
    | Generating
    | Success
    | Failed String


type alias Model =
    { prompt : String
    , generationStatus : GenerationStatus
    , tours : List Tour
    , settings : LLMSettings
    , key : Nav.Key
    , route : Route
    }


type Msg
    = NoOp
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | UpdatePrompt String
    | GenerateTour
    | LLMResponseReceived (Result Http.Error LLMResponse)
    | ToursLoaded (List Tour)
    | ToggleTourStop Int
    | UpdateEndpoint String
    | UpdateModel String
    | UpdateApiKey String
    | SaveSettings
    | SettingsSaved
    | SettingsLoaded (Maybe LLMSettings)


main : Program IO.Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }


init : IO.Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( { key = key
      , tours = []
      , prompt = "A tour of Krakow Poland"
      , generationStatus = Idle
      , settings = flags.llmSettings
      , route = Routes.fromUrl url
      }
    , Cmd.batch [ IO.fromElm IO.LoadTours, IO.fromElm IO.LoadSettings ]
    )


subscriptions : Model -> Sub Msg
subscriptions _ =
    IO.toElm
        |> Sub.map
            (\result ->
                case result of
                    Ok data ->
                        case data of
                            IO.SettingsSaved ->
                                SettingsSaved

                            IO.ToursLoaded tours ->
                                ToursLoaded tours

                            IO.SettingsLoaded settings ->
                                SettingsLoaded settings

                    Err _ ->
                        NoOp
            )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LinkClicked request ->
            case request of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | route = Routes.fromUrl url }, Cmd.none )

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
                                stopsWithExpanded : List TourStop
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

                                tour : Tour
                                tour =
                                    { id = tourData.id
                                    , title = tourData.title
                                    , description = tourData.description
                                    , coordinates = tourData.coordinates
                                    , stops = stopsWithExpanded
                                    }
                            in
                            ( { model
                                | generationStatus = Success
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

        ToggleTourStop index ->
            case model.route of
                Routes.TourRoute id ->
                    let
                        updateTour : Tour -> Tour
                        updateTour tour =
                            if tour.id == id then
                                let
                                    newStops : List TourStop
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

                        newTours : List Tour
                        newTours =
                            List.map updateTour model.tours
                    in
                    ( { model | tours = newTours }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ToursLoaded tours ->
            ( { model | tours = tours }, Cmd.none )

        UpdateEndpoint value ->
            let
                settings : LLMSettings
                settings =
                    model.settings

                newSettings : LLMSettings
                newSettings =
                    { settings | endpoint = value }
            in
            ( { model | settings = newSettings }, Cmd.none )

        UpdateModel value ->
            let
                settings : LLMSettings
                settings =
                    model.settings

                newSettings : LLMSettings
                newSettings =
                    { settings | model = value }
            in
            ( { model | settings = newSettings }, Cmd.none )

        UpdateApiKey value ->
            let
                settings : LLMSettings
                settings =
                    model.settings

                newSettings : LLMSettings
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

        SettingsLoaded maybeSettings ->
            case maybeSettings of
                Just loadedSettings ->
                    ( { model | settings = loadedSettings }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )


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
        , ( "stream", Json.Encode.bool False )
        , ( "format", Json.Encode.string "json" )
        ]


createPromptTemplate : String -> String
createPromptTemplate prompt =
    "Create a walking tour based on this prompt: \""
        ++ prompt
        ++ "\". \n\n"
        ++ "Respond with a raw JSON object containing all of the required properties: "
        ++ "- id: a unique string id "
        ++ "- title: short but creative title - avoid using words walking and tour "
        ++ "- description: a general description of the tour "
        ++ "- coordinates: an object with latitude and longitude of the main city or area "
        ++ "- stops: an array of stops, each with: "
        ++ "  - title: a short title for the stop "
        ++ "  - description: a detailed description of the stop "
        ++ "  - coordinates: an object with latitude and longitude of this specific stop"


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
    , title : String
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
    Json.Decode.map5 TourData
        (Json.Decode.field "id" Json.Decode.string)
        (Json.Decode.field "title" Json.Decode.string)
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


view : Model -> Browser.Document Msg
view model =
    { title = "Tour Generator"
    , body =
        [ div [ class "min-h-screen bg-base-100" ]
            [ viewNavigation model.route
            , div [ class "container mx-auto p-4" ]
                [ case model.route of
                    HomeRoute ->
                        viewHome model

                    ToursRoute ->
                        viewTours model.tours

                    TourRoute id ->
                        viewTour id model.tours

                    SettingsRoute ->
                        viewSettings model.settings

                    NotFoundRoute ->
                        div [ class "text-center" ]
                            [ h1 [ class "text-4xl font-bold" ] [ text "Page Not Found" ]
                            , p [ class "mt-4" ] [ text "The page you're looking for doesn't exist." ]
                            ]
                ]
            ]
        ]
    }


active : b -> b -> String -> Html.Attribute msg
active a b cls =
    if a == b then
        class cls

    else
        class ""


viewNavigation : Route -> Html Msg
viewNavigation route =
    div
        [ class "navbar bg-base-100 shadow-sm"
        ]
        [ div
            [ class "flex-1"
            ]
            [ a
                [ class "btn btn-ghost text-xl text-primary"
                , href (Routes.toUrl HomeRoute)
                ]
                [ text "TourGen" ]
            ]
        , div
            [ class "flex-none"
            ]
            [ ul
                [ class "menu menu-horizontal px-1"
                ]
                [ li []
                    [ a [ href (Routes.toUrl HomeRoute), active route HomeRoute "menu-active" ]
                        [ text "Home" ]
                    ]
                , li []
                    [ a [ href (Routes.toUrl ToursRoute), active route ToursRoute "menu-active" ]
                        [ text "Tours" ]
                    ]
                , li []
                    [ a [ href (Routes.toUrl SettingsRoute), active route SettingsRoute "menu-active" ]
                        [ text "Settings" ]
                    ]
                ]
            ]
        ]


viewHome : Model -> Html Msg
viewHome model =
    div [ class "max-w-2xl mx-auto" ]
        [ h1 [ class "text-4xl font-bold text-center mb-8" ] [ text "Generate Your Walking Tour" ]
        , div [ class "card bg-base-200 shadow-xl" ]
            [ div [ class "card-body" ]
                [ form [ class "flex flex-col", onSubmit GenerateTour ]
                    [ input
                        [ class "input input-lg input-bordered w-full"
                        , placeholder "A two hour walking tour around Kraków, Poland. Include museums, historical landmarks and a place with good food."
                        , value model.prompt
                        , onInput UpdatePrompt
                        ]
                        []
                    , div [ class "form-control mt-6" ]
                        [ button
                            [ class "btn btn-primary"
                            , type_ "submit"
                            , disabled (String.isEmpty (String.trim model.prompt) || model.generationStatus == Generating)
                            ]
                            (case model.generationStatus of
                                Generating ->
                                    [ text "Generating", span [ class "loading loading-infinity" ] [] ]

                                _ ->
                                    [ text "Generate" ]
                            )
                        ]
                    ]
                ]
            ]
        , case model.generationStatus of
            Failed error ->
                div [ class "alert alert-error mt-4" ]
                    [ text ("Error: " ++ error) ]

            _ ->
                text ""
        , if List.isEmpty model.tours then
            text ""

          else
            div [ class "mt-8" ]
                [ h2 [ class "text-2xl font-bold mb-4" ] [ text "Recent Tours" ]
                , div [ class "space-y-4" ]
                    (List.take 5 model.tours
                        |> List.map viewTourCard
                    )
                ]
        ]


viewTourCard : Tour -> Html Msg
viewTourCard tour =
    div [ class "card bg-base-200 shadow compact hover:shadow-lg transition-shadow" ]
        [ div [ class "card-body" ]
            [ h3 [ class "card-title text-lg" ]
                [ a [ href (Routes.toUrl (TourRoute tour.id)) ]
                    [ text
                        (String.left 60 tour.title
                            ++ (if String.length tour.title > 60 then
                                    "..."

                                else
                                    ""
                               )
                        )
                    ]
                ]
            , p [ class "text-sm opacity-70" ]
                [ text
                    (String.left 100 tour.description
                        ++ (if String.length tour.description > 100 then
                                "..."

                            else
                                ""
                           )
                    )
                ]
            , div [ class "text-xs opacity-50" ] [ text (String.fromInt (List.length tour.stops) ++ " stops") ]
            ]
        ]


viewTours : List Tour -> Html Msg
viewTours tours =
    div []
        [ h1 [ class "text-4xl font-bold mb-8" ] [ text "Your Tours" ]
        , if List.isEmpty tours then
            div [ class "text-center py-12" ]
                [ p [ class "text-lg opacity-70 mb-4" ] [ text "You haven't generated any tours yet." ]
                , a [ class "btn btn-primary", href (Routes.toUrl HomeRoute) ] [ text "Generate Your First Tour" ]
                ]

          else
            div [ class "grid gap-4 md:grid-cols-2 lg:grid-cols-3" ]
                (List.map viewTourCard tours)
        ]


viewTour : String -> List Tour -> Html Msg
viewTour tourId tours =
    case List.filter (\tour -> tour.id == tourId) tours |> List.head of
        Nothing ->
            div [ class "text-center" ]
                [ h1 [ class "text-4xl font-bold" ] [ text "Tour Not Found" ]
                , p [ class "mt-4" ] [ text "The tour you're looking for doesn't exist." ]
                , a [ class "btn btn-primary mt-4", href (Routes.toUrl HomeRoute) ] [ text "Go Home" ]
                ]

        Just tour ->
            div []
                [ h1 [ class "text-4xl font-bold mb-4" ] [ text "Tour Details" ]
                , div [ class "card bg-base-200 shadow-xl mb-6" ]
                    [ div [ class "card-body" ]
                        [ h2 [ class "card-title text-xl" ] [ text tour.title ]
                        , p [ class "mt-2" ] [ text tour.description ]
                        ]
                    ]
                , h2 [ class "text-2xl font-bold mb-4" ] [ text "Tour Stops" ]
                , div [ class "space-y-4" ]
                    (List.indexedMap (viewTourStop tourId) tour.stops)
                ]


viewTourStop : String -> Int -> TourStop -> Html Msg
viewTourStop _ index stop =
    div [ class "collapse collapse-arrow bg-base-200" ]
        [ input
            [ type_ "checkbox"
            , attribute "checked"
                (if stop.expanded then
                    "checked"

                 else
                    ""
                )
            , onClick (ToggleTourStop index)
            ]
            []
        , div [ class "collapse-title text-xl font-medium" ]
            [ text stop.title ]
        , div [ class "collapse-content" ]
            [ p [] [ text stop.description ] ]
        ]


viewSettings : LLMSettings -> Html Msg
viewSettings settings =
    div [ class "max-w-xl mx-auto" ]
        [ h1 [ class "text-4xl font-bold mb-8" ] [ text "Settings" ]
        , div [ class "card bg-base-200 shadow-xl" ]
            [ div [ class "card-body" ]
                [ h2 [ class "card-title mb-4" ] [ text "LLM Configuration" ]
                , div [ class "form-control flex items-center" ]
                    [ label [ class "label flex-1" ]
                        [ text "LLM Endpoint" ]
                    , input
                        [ class "input"
                        , type_ "url"
                        , placeholder "http://localhost:11434"
                        , value settings.endpoint
                        , onInput UpdateEndpoint
                        ]
                        []
                    ]
                , div [ class "form-control flex items-center" ]
                    [ label [ class "label flex-1" ]
                        [ text "Model" ]
                    , input
                        [ class "input input-bordered"
                        , type_ "text"
                        , placeholder "qwen3:8b"
                        , value settings.model
                        , onInput UpdateModel
                        ]
                        []
                    ]
                , div [ class "form-control flex items-center" ]
                    [ label [ class "label flex-1" ]
                        [ text "API Key" ]
                    , input
                        [ class "input input-bordered"
                        , type_ "password"
                        , placeholder "Optional API key"
                        , value settings.apiKey
                        , onInput UpdateApiKey
                        ]
                        []
                    ]
                , div [ class "form-control mt-6" ]
                    [ button [ class "btn btn-primary", onClick SaveSettings ] [ text "Save Settings" ]
                    ]
                ]
            ]
        ]
