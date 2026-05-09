module Env exposing
    ( Env
    , Flags
    , Msg
    , init
    , subscriptions
    , update
    )

{-| This module manages the central app environment that is shared across modules
-}

import Env.Auth exposing (Auth)
import Browser.Dom
import Browser.Events
import Task



-- MODEL


type alias Env =
    { -- auth
      auth : Auth

    -- dev
    , devMode : Bool

    -- Display
    , width : Float
    , height : Float
    }


type alias Flags =
    { baseUrl : String
    , devMode : Bool
    , accessToken : Maybe String
    , queryString : String
    }


init : ToMsg msg -> Flags -> ( Env, Cmd msg )
init toMsg flags =
    let
        ( auth, authCmd ) =
            initAuth toMsg flags
    in
    ( { auth = auth
      , devMode = flags.devMode
      , width = 0
      , height = 0
      }
    , Cmd.batch
        [ authCmd
        , initViewport toMsg
        ]
    )


initAuth : ToMsg msg -> Flags -> ( Auth, Cmd msg )
initAuth toMsg flags =
    Env.Auth.init
        (toMsg << GotAuthStatusMsg)
        flags.baseUrl
        flags.accessToken


initViewport : ToMsg msg -> Cmd msg
initViewport toMsg =
    Task.perform
        (\vp ->
            toMsg <|
                GotViewport
                    vp.viewport.width
                    vp.viewport.height
        )
        Browser.Dom.getViewport



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotViewport Float Float
    | GotAuthStatusMsg Env.Auth.Msg


update : Msg -> Env -> ( Env, Cmd msg )
update msg env =
    case msg of
        GotViewport width height ->
            ( { env | width = width, height = height }, Cmd.none )

        GotAuthStatusMsg subMsg ->
            let
                ( newAuth, cmd ) =
                    Env.Auth.update subMsg env.auth
            in
            ( { env | auth = newAuth }, cmd )



-- SUBSCRIPTIONS


subscriptions : ToMsg msg -> Sub msg
subscriptions toMsg =
    Browser.Events.onResize
        (\w h -> toMsg <| GotViewport (toFloat w) (toFloat h))
