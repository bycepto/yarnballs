module Main exposing (main)

import Browser exposing (Document)
import Css as C
import Env exposing (Env)
import Html.Styled as H
import Html.Styled.Attributes as At
import Yarnballs exposing (Yarnballs)



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
    }


type Page
    = Game Yarnballs



-- INITIALIZE


init : Env.Flags -> ( Model, Cmd Msg )
init flags =
    let
        ( env, envCmd ) =
            Env.init GotEnvMsg flags

        ( game, gameCmd ) =
            Yarnballs.init
    in
    ( { env = env
      , page = Game game
      }
    , Cmd.batch
        [ envCmd
        , gameCmd
        ]
    )



-- UPDATE


type Msg
    = GotEnvMsg Env.Msg
    | GotPageYarnballsMsg Yarnballs.Msg


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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Env.subscriptions GotEnvMsg
        , case model.page of
            Game page ->
                Yarnballs.subscriptions GotPageYarnballsMsg page.ws
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
