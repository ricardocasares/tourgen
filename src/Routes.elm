module Routes exposing (Route(..), fromUrl, toUrl)

import Url
import Url.Parser as Parser exposing ((</>), Parser, map, oneOf, s, string, top)


type Route
    = HomeRoute
    | ToursRoute
    | TourRoute String
    | SettingsRoute
    | NotFoundRoute


parser : Parser (Route -> a) a
parser =
    oneOf
        [ map HomeRoute top
        , map ToursRoute (s "tours")
        , map TourRoute (s "tour" </> string)
        , map SettingsRoute (s "settings")
        ]


fromUrl : Url.Url -> Route
fromUrl url =
    url
        |> Parser.parse parser
        |> Maybe.withDefault NotFoundRoute


toUrl : Route -> String
toUrl route =
    case route of
        HomeRoute ->
            "/"

        ToursRoute ->
            "/tours"

        TourRoute tourId ->
            "/tour/" ++ tourId

        SettingsRoute ->
            "/settings"

        NotFoundRoute ->
            "/404"
