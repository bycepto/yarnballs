module Yarnballs.Page.Room exposing
    ( Msg
    , Page
    , init
    , load
    , subscriptions
    , unload
    , update
    , view
    )

{-| Represents the page for a Yarnballs room
-}

import App.AuthStatus exposing (AuthStatus)
import App.User exposing (UserId)
import App.WebSocket exposing (WebSocket)
import Browser.Events as BE
import Canvas as V
import Canvas.Texture as VT
import Html as H
import Html.Attributes as At
import Json.Decode as D
import Json.Decode.Pipeline as DP
import Json.Encode as E
import Keyboard as K
import Yarnballs.Boom exposing (Booms)
import Yarnballs.Enemy exposing (Enemies)
import Yarnballs.Missile exposing (Missiles)
import Yarnballs.Ship exposing (Ships)



-- MODEL


type alias Page =
    { error : Maybe String

    -- game state
    , tick : Float
    , pressedKeys : List K.Key

    -- entities
    , ships : Ships
    , enemies : Enemies
    , missiles : Missiles
    , booms : Booms
    }


type alias Env a =
    { a
        | -- Http
          auth : AuthStatus

        -- WebSocket
        , ws : WebSocket

        -- Dev
        , devMode : Bool
    }


load : WebSocket -> Cmd msg
load ws =
    if App.WebSocket.isConnected ws then
        App.WebSocket.join topic

    else
        Cmd.none


unload : WebSocket -> Cmd msg
unload ws =
    if App.WebSocket.isConnected ws then
        App.WebSocket.leave topic

    else
        Cmd.none


topic : App.WebSocket.Topic
topic =
    -- App.WebSocket.toTopic "yarnballs" "d8fa592d-488f-423b-94f2-7fd9dd014c90"
    App.WebSocket.toTopic "yarnballs" "x"


joined : WebSocket -> Bool
joined ws =
    App.WebSocket.joined topic ws


type alias Entity a =
    { a
        | x : Float
        , y : Float
        , velX : Float
        , velY : Float
    }


handleEntityPhysicsWithFriction : Entity a -> Entity a
handleEntityPhysicsWithFriction entity =
    { entity
        | x = entity.x + entity.velX
        , y = entity.y + entity.velY
        , velX = entity.velX * (1 - friction)
        , velY = entity.velY * (1 - friction)
    }


wrap : Entity a -> Entity a
wrap entity =
    { entity
        | x = toFloat <| modBy (round width) (round entity.x)
        , y = toFloat <| modBy (round height) (round entity.y)
    }


type alias Textured a =
    { a
        | texture : Maybe VT.Texture
    }


setTextureOnce : Maybe VT.Texture -> Textured a -> Textured a
setTextureOnce texture textured =
    case textured.texture of
        Nothing ->
            { textured | texture = texture }

        Just _ ->
            textured


init : Page
init =
    { error = Nothing
    , tick = 0
    , pressedKeys = []
    , ships = Yarnballs.Ship.init
    , enemies = Yarnballs.Enemy.init
    , missiles = Yarnballs.Missile.init
    , booms = Yarnballs.Boom.init
    }



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotWebSocketAppMsg App.WebSocket.Msg
    | GotWebSocketMessage E.Value
    | GotKeyPress K.Msg
    | GotKeyDown K.RawKey
    | GotEnemy (Maybe VT.Texture)
    | GotShip (Maybe VT.Texture)
    | GotMissile (Maybe VT.Texture)
    | GotBoom (Maybe VT.Texture)
    | Frame Float


update : Msg -> Env a -> Page -> ( Page, Cmd msg, Env a )
update msg env page =
    case msg of
        GotWebSocketAppMsg subMsg ->
            (case App.AuthStatus.toUser env.auth of
                Nothing ->
                    ( env, Cmd.none )

                Just user ->
                    env.ws
                        |> App.WebSocket.update subMsg user
                        |> Tuple.mapFirst (\ws -> { env | ws = ws })
            )
                |> (\( m, cmd ) -> ( page, cmd, m ))

        GotWebSocketMessage serialized ->
            case App.AuthStatus.toUser env.auth of
                Nothing ->
                    ( page, Cmd.none, env )

                Just user ->
                    ( handleWebSocketMessage user.id serialized page, Cmd.none, env )

        GotKeyPress keyMsg ->
            ( { page | pressedKeys = K.update keyMsg page.pressedKeys }, Cmd.none, env )

        GotKeyDown rawKey ->
            if not (joined env.ws) then
                ( page, Cmd.none, env )

            else
                case K.anyKeyUpper rawKey of
                    Just K.Spacebar ->
                        ( page, Yarnballs.Ship.fireShot topic page.ships, env )

                    _ ->
                        ( page, Cmd.none, env )

        GotEnemy texture ->
            ( { page | enemies = setTextureOnce texture page.enemies }, Cmd.none, env )

        GotShip texture ->
            ( { page | ships = setTextureOnce texture page.ships }
            , Cmd.none
            , env
            )

        GotMissile texture ->
            ( { page | missiles = setTextureOnce texture page.missiles }, Cmd.none, env )

        GotBoom texture ->
            ( { page | booms = setTextureOnce texture page.booms }, Cmd.none, env )

        Frame _ ->
            let
                newPage =
                    handleFrameUpdate page
            in
            if joined env.ws then
                ( newPage, Yarnballs.Ship.move topic newPage.ships, env )

            else
                ( newPage, Cmd.none, env )


handleWebSocketMessage : UserId -> E.Value -> Page -> Page
handleWebSocketMessage userId serialized page =
    case D.decodeValue (App.WebSocket.decodeMessage eventFromString) serialized of
        Err _ ->
            -- cannot record error hear since other events come through like `phx_reply`
            page

        Ok message ->
            case App.WebSocket.fromEvent message.event of
                RequestedState ->
                    case D.decodeValue (decode userId page) message.payload of
                        Ok newPage ->
                            newPage

                        Err error ->
                            { page | error = Just (D.errorToString error) }


decode : UserId -> Page -> D.Decoder Page
decode userId page =
    D.map
        (handleDecoded page)
        (decodeState userId page)


handleDecoded : Page -> State -> Page
handleDecoded page state =
    { page
        | error = Nothing
        , enemies = state.enemies
        , missiles = state.missiles
        , booms = state.booms
        , ships = state.ships
    }


type alias State =
    -- TODO: is this struct superfluous?
    { enemies : Enemies
    , missiles : Missiles
    , ships : Ships
    , booms : Booms
    }


decodeState : UserId -> Page -> D.Decoder State
decodeState userId page =
    D.succeed State
        |> DP.requiredAt [ "state", "enemies", "entities" ] (Yarnballs.Enemy.decode page.enemies)
        |> DP.requiredAt [ "state", "missiles", "entities" ] (Yarnballs.Missile.decode page.missiles)
        |> DP.requiredAt [ "state", "ships", "entities" ] (Yarnballs.Ship.decode userId page.ships)
        |> DP.requiredAt [ "state", "enemies", "explosions", "entities" ] (Yarnballs.Boom.decode page.tick page.booms)


type ReceivedEvent
    = RequestedState


eventFromString : String -> Maybe ReceivedEvent
eventFromString s =
    case s of
        "requested_state" ->
            Just RequestedState

        _ ->
            Nothing


handleFrameUpdate : Page -> Page
handleFrameUpdate page =
    page
        |> handleKeyPresses
        |> handlePhysics
        |> updateTick


handlePhysics : Page -> Page
handlePhysics page =
    -- TODO: move to Ship module?
    let
        ships =
            page.ships
    in
    { page
        | ships =
            { ships
                | ship = (wrap << handleEntityPhysicsWithFriction) ships.ship
            }
    }


updateTick : Page -> Page
updateTick page =
    { page | tick = page.tick + 1 }


handleKeyPresses : Page -> Page
handleKeyPresses page =
    { page
        | ships = Yarnballs.Ship.handleKeyPresses page.pressedKeys page.ships
    }


friction : Float
friction =
    0.05



-- SUBSCRIPTIONS


subscriptions : ToMsg msg -> WebSocket -> Sub msg
subscriptions toMsg ws =
    Sub.batch
        [ BE.onAnimationFrameDelta (toMsg << Frame)
        , subscribeKeyboard toMsg
        , App.WebSocket.joinUntilSuccess (toMsg << GotWebSocketAppMsg) topic ws
        , App.WebSocket.messageReceiver (toMsg << GotWebSocketMessage)
        ]


subscribeKeyboard : ToMsg msg -> Sub msg
subscribeKeyboard toMsg =
    -- Note that arrow keys are not triggered for onkeypress
    -- https://stackoverflow.com/questions/5597060/detecting-arrow-key-presses-in-javascript
    -- BE.onKeyDown (D.map (toMsg << GotKeyPress) keyDecoder)
    Sub.batch
        [ Sub.map (toMsg << GotKeyPress) K.subscriptions
        , K.downs (toMsg << GotKeyDown)
        ]



-- VIEWS


view : ToMsg msg -> Env a -> Page -> { title : String, content : H.Html msg }
view toMsg env page =
    { title = "Yarnballs Room"
    , content = viewBody toMsg env page
    }


viewBody : ToMsg msg -> Env a -> Page -> H.Html msg
viewBody toMsg env page =
    if not (joined env.ws) then
        H.div [] [ H.text "Loading..." ]

    else
        case page.error of
            Just error ->
                H.div []
                    [ H.text <|
                        "Error loading page"
                            ++ (if env.devMode then
                                    ": " ++ error

                                else
                                    "!"
                               )
                    ]

            Nothing ->
                H.div
                    [ -- flex
                      At.style "display" "flex"
                    , At.style "justify-content" "center"
                    , At.style "align-items" "center"
                    , At.style "column-gap" "1em"

                    -- size
                    , At.style "width" "100%"
                    , At.style "height" "100%"
                    ]
                    [ viewGame toMsg page
                    , viewCredits
                    ]


viewCredits : H.Html msg
viewCredits =
    H.div
        []
        [ H.div [ At.style "font-weight" "bold" ] [ H.text "Artwork credits" ]
        , H.div [] [ H.text "Kim Lathrop (ship and missiles)" ]
        , H.div
            []
            [ H.a [ At.href "http://robsonbillponte666.deviantart.com" ] [ H.text "Rob" ]
            , H.text " (yarn balls)"
            ]
        ]


viewGame : ToMsg msg -> Page -> H.Html msg
viewGame toMsg page =
    V.toHtmlWith
        { width = width
        , height = height
        , textures = loadTextures toMsg
        }
        [ At.style "border" "10px solid rgba(0,0,0,0.1)"
        ]
    <|
        render page


loadTextures : ToMsg msg -> List (VT.Source msg)
loadTextures toMsg =
    [ Yarnballs.Enemy.loadTexture (toMsg << GotEnemy)
    , Yarnballs.Ship.loadTexture (toMsg << GotShip)
    , Yarnballs.Missile.loadTexture (toMsg << GotMissile)
    , Yarnballs.Boom.loadTexture (toMsg << GotBoom)
    ]


render : Page -> List V.Renderable
render page =
    List.concat
        [ [ V.clear ( 0, 0 ) width height ]
        , Yarnballs.Enemy.render page.tick page.enemies
        , Yarnballs.Missile.render page.missiles
        , Yarnballs.Ship.render page.ships
        , Yarnballs.Boom.render page.tick page.booms
        ]


width : number
width =
    640


height : number
height =
    480
