module Yarnballs exposing
    ( Msg
    , Yarnballs
    , init
    , load
    , subscriptions
    , unload
    , update
    , view
    )

{-| Represents the yb for a Yarnballs room
-}

import Color
import Css as C
import Css.Animations as An
import Env exposing (Env)
import Env.Auth exposing (Status(..))
import Env.User exposing (UserId)
import Html.Styled as H
import Html.Styled.Attributes as At
import Json.Decode as D
import Json.Encode as E
import Login exposing (Login)
import Utils
import VitePluginHelper as VPH
import WebSocket exposing (WebSocket)
import Yarnballs.Game exposing (Game)



-- MODEL


type alias Yarnballs =
    { error : Maybe String
    , game : Game
    , login : Login
    , ws : WebSocket
    }


load : WebSocket -> Cmd msg
load ws =
    if WebSocket.isConnected ws then
        WebSocket.join topic

    else
        Cmd.none


unload : WebSocket -> Cmd msg
unload ws =
    if WebSocket.isConnected ws then
        Cmd.batch
            [ WebSocket.leave topic
            , WebSocket.disconnect
            ]

    else
        Cmd.none


topic : WebSocket.Topic
topic =
    WebSocket.toTopic "yarnballs" "x"


joined : WebSocket -> Bool
joined ws =
    WebSocket.joined topic ws


init : ( Yarnballs, Cmd msg )
init =
    let
        ( login, loginCmd ) =
            Login.init
    in
    ( { error = Nothing
      , game = Yarnballs.Game.init
      , login = login
      , ws = WebSocket.init
      }
    , loginCmd
    )



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotWebSocketSetupMsg WebSocket.Msg
    | GotWebSocketEventMsg E.Value
    | GotLoginMsg Login.Msg
    | GotYarnballsMsg Yarnballs.Game.Msg


update : ToMsg msg -> Msg -> Env -> Yarnballs -> ( Yarnballs, Cmd msg, Env )
update toMsg msg env yb =
    case msg of
        GotWebSocketSetupMsg subMsg ->
            case Env.Auth.toUser env.auth of
                Nothing ->
                    ( yb, Cmd.none, env )

                Just user ->
                    let
                        ( ws, cmd ) =
                            WebSocket.update subMsg user.accessToken yb.ws
                    in
                    ( { yb | ws = ws }, cmd, env )

        GotWebSocketEventMsg serialized ->
            case Env.Auth.toUser env.auth of
                Nothing ->
                    ( yb, Cmd.none, env )

                Just user ->
                    ( handleWebSocketMessage user.id serialized yb, Cmd.none, env )

        GotLoginMsg subMsg ->
            let
                ( login, cmd, newEnv ) =
                    Login.update env (toMsg << GotLoginMsg) subMsg yb.login
            in
            ( { yb | login = login }
            , cmd
            , newEnv
            )

        GotYarnballsMsg subMsg ->
            let
                ( game, cmd ) =
                    Yarnballs.Game.update subMsg topic yb.game
            in
            ( { yb | game = game }, cmd, env )


handleWebSocketMessage : UserId -> E.Value -> Yarnballs -> Yarnballs
handleWebSocketMessage userId serialized yb =
    case D.decodeValue decodeMessage serialized of
        Err _ ->
            -- we should not record error here since this branch captures valid
            -- auxilary events like `phx_reply`
            yb

        Ok message ->
            case WebSocket.fromEvent message.event of
                RequestedState ->
                    case D.decodeValue (Yarnballs.Game.decode userId yb.game) message.payload of
                        Ok game ->
                            { yb | game = game }

                        Err error ->
                            { yb | error = Just (D.errorToString error) }


decodeMessage : D.Decoder (WebSocket.Message ReceivedEvent)
decodeMessage =
    WebSocket.decodeMessage ((==) topic) eventFromString


type ReceivedEvent
    = RequestedState


eventFromString : String -> Maybe ReceivedEvent
eventFromString s =
    case s of
        "requested_state" ->
            Just RequestedState

        _ ->
            Nothing



-- SUBSCRIPTIONS


subscriptions : ToMsg msg -> WebSocket -> Sub msg
subscriptions toMsg ws =
    Sub.batch
        [ Yarnballs.Game.subscriptions (toMsg << GotYarnballsMsg)
        , Login.subscriptions (toMsg << GotLoginMsg)
        , webSocketSubscriptions toMsg ws
        ]


webSocketSubscriptions : ToMsg msg -> WebSocket -> Sub msg
webSocketSubscriptions toMsg ws =
    Sub.batch
        [ WebSocket.subscriptions (toMsg << GotWebSocketSetupMsg) topic ws
        , WebSocket.messageReceiver (toMsg << GotWebSocketEventMsg)
        ]



-- VIEWS


view : Env -> ToMsg msg -> Yarnballs -> { title : String, content : H.Html msg }
view env toMsg yb =
    { title = "Yarnballs"
    , content = viewBody env toMsg yb
    }


viewBody : Env -> ToMsg msg -> Yarnballs -> H.Html msg
viewBody env toMsg yb =
    H.div
        [ At.css
            [ -- size
              C.width (C.pct 100)
            , C.height (C.pct 100)

            -- flex
            , C.displayFlex
            , C.justifyContent C.center
            , C.alignItems C.center

            -- prevent scrolling
            , C.overflowX C.hidden
            ]
        ]
        [ H.div
            [ At.css <|
                if yb.game.shakeFor > 0 then
                    styleShake

                else
                    []
            ]
            [ viewGameScaled env toMsg yb ]
        ]


viewLoading : H.Html msg
viewLoading =
    H.div
        [ At.css
            [ -- flex / center
              C.displayFlex
            , C.flexDirection C.column
            , C.property "row-gap" "2em"
            , C.justifyContent C.center
            , C.alignItems C.center
            , C.height (C.pct 100)
            ]
        ]
        [ Utils.loadingSpinner Color.white
        , H.div
            [ At.css
                [ C.fontSize (C.em 1.5)
                , C.color (Utils.fromColor Color.white)
                ]
            ]
            [ H.text "Loading..." ]
        ]


viewLoadingError : Env -> String -> H.Html msg
viewLoadingError env errorMsg =
    H.div
        [ At.css
            [ -- center
              C.displayFlex
            , C.justifyContent C.center
            , C.alignItems C.center
            , C.height (C.pct 100)
            ]
        ]
        [ H.text <|
            "Error loading yb"
                ++ (if env.devMode then
                        ": " ++ errorMsg

                    else
                        "!"
                   )
        ]


styleShake : List C.Style
styleShake =
    -- https://css-tricks.com/snippets/css/shake-css-keyframe-animation/
    [ C.animationName <|
        An.keyframes
            [ ( 0, [ An.property "transform" "translate3d(0, 0, 0)" ] )
            , ( 10, [ An.property "transform" "translate3d(-1px, 0, 0)" ] )
            , ( 20, [ An.property "transform" "translate3d(2px, 0, 0)" ] )
            , ( 30, [ An.property "transform" "translate3d(-4px, 0, 0)" ] )
            , ( 40, [ An.property "transform" "translate3d(4px, 0, 0)" ] )
            , ( 50, [ An.property "transform" "translate3d(-4px, 0, 0)" ] )
            , ( 60, [ An.property "transform" "translate3d(4px, 0, 0)" ] )
            , ( 70, [ An.property "transform" "translate3d(-4px, 0, 0)" ] )
            , ( 80, [ An.property "transform" "translate3d(2px, 0, 0)" ] )
            , ( 90, [ An.property "transform" "translate3d(-1px, 0, 0)" ] )
            , ( 100, [ An.property "transform" "translate3d(0, 0, 0)" ] )
            ]
    , C.animationDuration (C.sec 0.82)
    , C.property "animation-timing-function" "cubic-bezier"
    , C.property "animation-fill-mode" "both"
    , C.property "animation-iteration-count" "infinite"
    ]


viewGameScaled : Env -> ToMsg msg -> Yarnballs -> H.Html msg
viewGameScaled env toMsg yb =
    H.div
        [ At.css <|
            if Env.isMobile env then
                [ C.transform (C.scale 0.8)
                ]

            else
                []
        , At.css
            [ -- flex
              C.displayFlex
            , C.justifyContent C.center
            , C.alignItems C.center
            , C.property "column-gap" "1em"
            ]
        ]
        [ viewGame env toMsg yb
        , if Env.isMobile env then
            H.text ""

          else
            viewInfo
        ]


viewGame : Env -> ToMsg msg -> Yarnballs -> H.Html msg
viewGame env toMsg yb =
    H.div
        [ At.css
            [ C.border3 (C.px 2) C.solid (Utils.fromColor Color.grey)
            , C.width (C.px Yarnballs.Game.width)
            , C.height (C.px Yarnballs.Game.height)
            , C.backgroundImage <|
                C.url (VPH.asset "/src/images/yarnballs/nebula_blue.s2014.png")
            ]
        ]
        [ case Env.Auth.getStatus env.auth of
            Loading ->
                viewLoading

            SignedOut ->
                .content <|
                    Login.view (toMsg << GotLoginMsg) Color.white yb.login

            SignedIn _ ->
                if not (joined yb.ws) then
                    viewLoading

                else
                    case yb.error of
                        Just error ->
                            viewLoadingError env error

                        Nothing ->
                            Yarnballs.Game.view (toMsg << GotYarnballsMsg) yb.game
        ]


viewInfo : H.Html msg
viewInfo =
    H.div
        []
        [ viewObjective
        , viewControls
        , viewCredits
        ]


viewInfoHeader : String -> H.Html msg
viewInfoHeader text =
    H.h4
        [ At.style "font-weight" "bold"
        , At.style "text-align" "center"
        ]
        [ H.text text ]


viewObjective : H.Html msg
viewObjective =
    H.div
        []
        [ viewInfoHeader "Gameplay"
        , H.div [] [ H.text "Shoot down yarnballs and rocks." ]
        , H.div [] [ H.text "Yarnballs bounce you, rocks hurt you." ]
        , H.div [] [ H.text "Get the highest collective score." ]
        , H.div [] [ H.text "Leaving the game voids your contribution." ]
        ]


viewControls : H.Html msg
viewControls =
    H.div
        []
        [ H.h4
            [ At.style "font-weight" "bold"
            , At.style "text-align" "center"
            ]
            [ H.text "Controls" ]
        , H.div [] [ H.text "Spacebar - fire missiles (hold), respawn" ]
        , H.div [] [ H.text "Up - thrust forward" ]
        , H.div [] [ H.text "Left - turn left" ]
        , H.div [] [ H.text "Right - turn right" ]
        ]


viewCredits : H.Html msg
viewCredits =
    H.div
        []
        [ H.h4
            [ At.style "font-weight" "bold"
            , At.style "text-align" "center"
            ]
            [ H.text "Artwork credits" ]
        , H.div []
            [ H.a
                [ At.href "http://robsonbillponte666.deviantart.com" ]
                [ H.text "Rob" ]
            , H.text " - yarnballs"
            ]
        , H.div [] [ H.text "Kim Lathrop - everything else" ]
        ]
