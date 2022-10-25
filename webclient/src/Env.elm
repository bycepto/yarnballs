module Env exposing
    ( Env
    , Flags
    , Msg
    , init
    , isMobile
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
    }


type alias Flags =
    { baseUrl : String
    , devMode : Bool
    , refreshToken : Maybe String
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
        flags.refreshToken


initViewport : ToMsg msg -> Cmd msg
initViewport toMsg =
    Task.perform
        (\vp -> (toMsg << GotViewportWidth) vp.viewport.width)
        Browser.Dom.getViewport


isMobile : Env -> Bool
isMobile { width } =
    width <= 900



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotViewportWidth Float
    | GotAuthStatusMsg Env.Auth.Msg


update : Msg -> Env -> ( Env, Cmd msg )
update msg env =
    case msg of
        GotViewportWidth width ->
            ( { env | width = width }, Cmd.none )

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
        (\w _ -> (toMsg << GotViewportWidth) (toFloat w))
