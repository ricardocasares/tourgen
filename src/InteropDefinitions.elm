module InteropDefinitions exposing (Coordinates, Flags, FromElm(..), LLMSettings, ToElm(..), Tour, TourStop, interop)

import TsJson.Codec as Codec exposing (Codec)
import TsJson.Decode as Decode exposing (Decoder)
import TsJson.Encode exposing (Encoder)


interop :
    { flags : Decoder Flags
    , toElm : Decoder ToElm
    , fromElm : Encoder FromElm
    }
interop =
    { flags = flags
    , toElm = toElm |> Codec.decoder
    , fromElm = fromElm |> Codec.encoder
    }


type alias Flags =
    { basePath : String
    , llmSettings : LLMSettings
    }


flags : Decoder Flags
flags =
    Decode.map2 Flags
        (Decode.field "basePath" Decode.string)
        (Decode.field "llmSettings" llmSettingsDecoder)


type alias LLMSettings =
    { endpoint : String
    , model : String
    , apiKey : String
    }


llmSettingsDecoder : Decoder LLMSettings
llmSettingsDecoder =
    Decode.map3 LLMSettings
        (Decode.field "endpoint" Decode.string)
        (Decode.field "model" Decode.string)
        (Decode.field "apiKey" Decode.string)


llmSettingsCodec : Codec LLMSettings
llmSettingsCodec =
    Codec.object LLMSettings
        |> Codec.field "endpoint" .endpoint Codec.string
        |> Codec.field "model" .model Codec.string
        |> Codec.field "apiKey" .apiKey Codec.string
        |> Codec.buildObject


type alias Coordinates =
    { latitude : Float
    , longitude : Float
    }


coordinatesCodec : Codec Coordinates
coordinatesCodec =
    Codec.object Coordinates
        |> Codec.field "latitude" .latitude Codec.float
        |> Codec.field "longitude" .longitude Codec.float
        |> Codec.buildObject


type alias TourStop =
    { title : String
    , description : String
    , coordinates : Coordinates
    , expanded : Bool
    }


tourStopCodec : Codec TourStop
tourStopCodec =
    Codec.object TourStop
        |> Codec.field "title" .title Codec.string
        |> Codec.field "description" .description Codec.string
        |> Codec.field "coordinates" .coordinates coordinatesCodec
        |> Codec.field "expanded" .expanded Codec.bool
        |> Codec.buildObject


type alias Tour =
    { id : String
    , title : String
    , description : String
    , coordinates : Coordinates
    , stops : List TourStop
    }


tourCodec : Codec Tour
tourCodec =
    Codec.object Tour
        |> Codec.field "id" .id Codec.string
        |> Codec.field "title" .title Codec.string
        |> Codec.field "description" .description Codec.string
        |> Codec.field "coordinates" .coordinates coordinatesCodec
        |> Codec.field "stops" .stops (Codec.list tourStopCodec)
        |> Codec.buildObject


type ToElm
    = SettingsSaved
    | ToursLoaded (List Tour)
    | SettingsLoaded (Maybe LLMSettings)


toElm : Codec ToElm
toElm =
    Codec.custom (Just "tag")
        (\vSettingsSaved vToursLoaded vSettingsLoaded value ->
            case value of
                SettingsSaved ->
                    vSettingsSaved

                ToursLoaded tours ->
                    vToursLoaded tours

                SettingsLoaded settings ->
                    vSettingsLoaded settings
        )
        |> Codec.variant0 "SettingsSaved" SettingsSaved
        |> Codec.namedVariant1 "ToursLoaded" ToursLoaded ( "data", Codec.list tourCodec )
        |> Codec.namedVariant1 "SettingsLoaded" SettingsLoaded ( "data", Codec.maybe llmSettingsCodec )
        |> Codec.buildCustom


type FromElm
    = SaveSettings LLMSettings
    | SaveTour Tour
    | LoadTours
    | LoadSettings


fromElm : Codec FromElm
fromElm =
    Codec.custom (Just "tag")
        (\vSaveSettings vSaveTour vLoadTours vLoadSettings value ->
            case value of
                SaveSettings settings ->
                    vSaveSettings settings

                SaveTour tour ->
                    vSaveTour tour

                LoadTours ->
                    vLoadTours

                LoadSettings ->
                    vLoadSettings
        )
        |> Codec.namedVariant1 "SaveSettings" SaveSettings ( "data", llmSettingsCodec )
        |> Codec.namedVariant1 "SaveTour" SaveTour ( "data", tourCodec )
        |> Codec.variant0 "LoadTours" LoadTours
        |> Codec.variant0 "LoadSettings" LoadSettings
        |> Codec.buildCustom
