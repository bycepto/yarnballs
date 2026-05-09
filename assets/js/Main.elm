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
    , helpVisible : Bool
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
      , helpVisible = False
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
    | GotGlobalKey KeyPress


type alias KeyPress =
    { key : String
    , targetTagName : String
    , isContentEditable : Bool
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotEnvMsg envMsg ->
            let
                ( env, envCmd ) =
                    Env.update envMsg model.env
            in
            case model.page of
                Game page ->
                    ( { model | env = env }
                    , Cmd.batch
                        [ envCmd
                        , Yarnballs.syncViewport env page.ws
                        ]
                    )

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

        GotGlobalKey keyPress ->
            handleGlobalKey keyPress model


handleGlobalKey : KeyPress -> Model -> ( Model, Cmd Msg )
handleGlobalKey keyPress model =
    if shouldIgnoreGlobalKey keyPress then
        ( model, Cmd.none )

    else
        case keyPress.key of
            "?" ->
                ( { model | helpVisible = not model.helpVisible }, Cmd.none )

            "Escape" ->
                if model.helpVisible then
                    ( { model | helpVisible = False }, Cmd.none )

                else
                    ( model, Cmd.none )

            key ->
                if model.debugMetrics.available && String.toLower key == "x" then
                    let
                        visible =
                            not model.debugMetrics.visible

                        debugMetrics =
                            model.debugMetrics
                    in
                    ( { model
                        | debugMetrics = { debugMetrics | visible = visible }
                      }
                    , setDebugMetricsVisible visible
                    )

                else
                    ( model, Cmd.none )


shouldIgnoreGlobalKey : KeyPress -> Bool
shouldIgnoreGlobalKey { targetTagName, isContentEditable } =
    isContentEditable
        || List.member targetTagName [ "INPUT", "TEXTAREA", "SELECT" ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Env.subscriptions GotEnvMsg
        , case model.page of
            Game page ->
                Yarnballs.subscriptions GotPageYarnballsMsg page.ws
        , Browser.Events.onKeyDown decodeKeyPress
        ]


decodeKeyPress : D.Decoder Msg
decodeKeyPress =
    D.map3 KeyPress
        (D.field "key" D.string)
        (D.at [ "target", "tagName" ] D.string)
        (D.oneOf
            [ D.at [ "target", "isContentEditable" ] D.bool
            , D.succeed False
            ]
        )
        |> D.map GotGlobalKey



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
            [ H.div stylePage <|
                [ doc.content ]
                    ++ (if model.helpVisible then
                            [ viewHelpOverlay ]

                        else
                            []
                       )
            ]
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


viewHelpOverlay : H.Html Msg
viewHelpOverlay =
    H.div
        [ At.css
            [ C.position C.fixed
            , C.top C.zero
            , C.left C.zero
            , C.width (C.vw 100)
            , C.height (C.vh 100)
            , C.displayFlex
            , C.justifyContent C.center
            , C.alignItems C.center
            , C.padding2 (C.px 24) (C.px 24)
            , C.backgroundColor (C.rgba 4 8 15 0.82)
            , C.zIndex (C.int 1000)
            , C.boxSizing C.borderBox
            ]
        ]
        [ H.div
            [ At.css
                [ C.width (C.px 520)
                , C.maxWidth (C.pct 100)
                , C.maxHeight (C.pct 100)
                , C.overflowY C.auto
                , C.padding4 (C.px 24) (C.px 28) (C.px 24) (C.px 28)
                , C.borderRadius (C.px 14)
                , C.backgroundColor (C.rgb 10 16 24)
                , C.border3 (C.px 1) C.solid (C.rgba 160 190 220 0.28)
                , C.color (C.rgb 215 227 240)
                , C.boxShadow5 (C.px 0) (C.px 20) (C.px 45) (C.px 0) (C.rgba 0 0 0 0.35)
                , C.boxSizing C.borderBox
                ]
            ]
            [ H.div
                [ At.css
                    [ C.displayFlex
                    , C.justifyContent C.spaceBetween
                    , C.alignItems C.center
                    , C.marginBottom (C.px 18)
                    ]
                ]
                [ H.h3
                    [ At.css
                        [ C.margin C.zero
                        , C.fontSize (C.px 26)
                        ]
                    ]
                    [ H.text "Game Help" ]
                , H.div
                    [ At.css
                        [ C.fontSize (C.px 13)
                        , C.opacity (C.num 0.75)
                        ]
                    ]
                    [ H.text "Press ? or Esc to close" ]
                ]
            , Yarnballs.viewHelp
            ]
        ]
