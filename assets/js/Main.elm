port module Main exposing (main)

import Browser exposing (Document)
import Browser.Events
import Css as C
import Env exposing (Env)
import Html.Styled as H
import Html.Styled.Attributes as At
import Json.Decode as D
import Url
import Url.Parser as Parser exposing ((<?>), top)
import Url.Parser.Query as Query
import Yarnballs exposing (Yarnballs)


port setDebugMetricsVisible : Bool -> Cmd msg



-- PROGRAM


main : Program Env.Flags Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Model =
    { -- Env
      env : Env

    -- Page
    , page : Page
    , debugMetrics : DebugMetrics
    }


type Page
    = Game Yarnballs


type alias DebugMetrics =
    { available : Bool
    , visible : Bool
    }



-- INITIALIZE


init : Env.Flags -> ( Model, Cmd Msg )
init flags =
    let
        ( env, envCmd ) =
            Env.init GotEnvMsg flags

        ( game, gameCmd ) =
            Yarnballs.init

        debugMetrics =
            initDebugMetrics flags
    in
    ( { env = env
      , page = Game game
      , debugMetrics = debugMetrics
      }
    , Cmd.batch
        [ envCmd
        , gameCmd
        , setDebugMetricsVisible debugMetrics.visible
        ]
    )


initDebugMetrics : Env.Flags -> DebugMetrics
initDebugMetrics flags =
    let
        available =
            flags.devMode || hasDebugQuery flags.queryString
    in
    { available = available
    , visible = available
    }


hasDebugQuery : String -> Bool
hasDebugQuery queryString =
    let
        urlString =
            "https://yarnballs.local/" ++ normalizeQueryString queryString
    in
    case Url.fromString urlString of
        Nothing ->
            False

        Just url ->
            Parser.parse (top <?> Query.string "debug") url
                == Just (Just "1")


normalizeQueryString : String -> String
normalizeQueryString queryString =
    if String.isEmpty queryString then
        ""

    else if String.startsWith "?" queryString then
        queryString

    else
        "?" ++ queryString



-- UPDATE


type Msg
    = GotEnvMsg Env.Msg
    | GotPageYarnballsMsg Yarnballs.Msg
    | GotDebugKey String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotEnvMsg envMsg ->
            let
                ( env, envCmd ) =
                    Env.update envMsg model.env
            in
            ( { model | env = env }, envCmd )

        GotPageYarnballsMsg subMsg ->
            case model.page of
                Game page ->
                    let
                        ( newPage, cmd, env ) =
                            Yarnballs.update GotPageYarnballsMsg subMsg model.env page
                    in
                    ( { model
                        | env = env
                        , page = Game newPage
                      }
                    , cmd
                    )

        GotDebugKey key ->
            if model.debugMetrics.available && String.toLower key == "x" then
                let
                    visible =
                        not model.debugMetrics.visible

                    newDebugMetrics =
                        let
                            debugMetrics =
                                model.debugMetrics
                        in
                        { debugMetrics | visible = visible }
                in
                ( { model
                    | debugMetrics = newDebugMetrics
                  }
                , setDebugMetricsVisible visible
                )

            else
                ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Env.subscriptions GotEnvMsg
        , case model.page of
            Game page ->
                Yarnballs.subscriptions GotPageYarnballsMsg page.ws
        , if model.debugMetrics.available then
            Browser.Events.onKeyDown (D.map GotDebugKey (D.field "key" D.string))

          else
            Sub.none
        ]



-- VIEWS


view : Model -> Document Msg
view model =
    let
        doc =
            viewPage model
    in
    { title = doc.title
    , body =
        List.map
            H.toUnstyled
            [ H.div stylePage [ doc.content ] ]
    }


stylePage : List (H.Attribute Msg)
stylePage =
    [ At.css
        [ -- Prevent double-tap zoom
          C.touchAction C.manipulation

        -- Prevent scrollbar from changing width
        , C.width (C.vw 100)

        -- fill viewport
        , C.height (C.vh 100)
        ]
    ]


viewPage : Model -> { title : String, content : H.Html Msg }
viewPage model =
    case model.page of
        Game page ->
            Yarnballs.view model.env GotPageYarnballsMsg page
