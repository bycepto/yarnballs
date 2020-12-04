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
import Canvas.Settings as VS
import Canvas.Settings.Advanced as VA
import Canvas.Settings.Text as VST
import Canvas.Texture as VT
import Color
import Dict
import Html as H
import Html.Attributes as At
import Json.Decode as D
import Json.Decode.Pipeline as DP
import Json.Encode as E
import Keyboard as K
import Keyboard.Arrows as KA
import VitePluginHelper as VPH



-- MODEL


type alias Page =
    { error : Maybe String

    -- game state
    , tick : Float
    , pressedKeys : List K.Key

    -- entities
    , ship : Ship
    , otherShips : List OtherShip
    , yarnballs : Yarnballs
    , shots : Shots
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


type alias Yarnballs =
    { texture : Maybe VT.Texture
    , entities : List Yarnball
    }


type alias Yarnball =
    { id : String
    , x : Float
    , y : Float
    , velX : Float
    , velY : Float
    }


type alias Ship =
    { x : Float
    , y : Float
    , velX : Float
    , velY : Float
    , texture : Maybe VT.Texture

    -- ship specific
    , thrusting : Bool
    , angle : Float
    }


type alias OtherShip =
    { id : UserId
    , x : Float
    , y : Float
    , angle : Float
    , thrusting : Bool
    }


type alias Shots =
    { texture : Maybe VT.Texture
    , entities : List Shot
    }


type alias Shot =
    { x : Float
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
    , ship = Ship 0 0 0 0 Nothing False 0
    , otherShips = []
    , yarnballs = Yarnballs Nothing []
    , shots = Shots Nothing []
    }


yarnballScale : Float
yarnballScale =
    0.3



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotWebSocketAppMsg App.WebSocket.Msg
    | GotWebSocketMessage E.Value
    | GotKeyPress K.Msg
    | GotKeyDown K.RawKey
    | GotYarnball (Maybe VT.Texture)
    | GotShip (Maybe VT.Texture)
    | GotShot (Maybe VT.Texture)
    | Frame Float


update : ToMsg msg -> Msg -> Env a -> Page -> ( Page, Cmd msg, Env a )
update toMsg msg env page =
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
                        -- FIRE SHOT
                        ( page, spawnShot page.ship, env )

                    _ ->
                        ( page, Cmd.none, env )

        GotYarnball texture ->
            ( { page | yarnballs = setTextureOnce texture page.yarnballs }, Cmd.none, env )

        GotShip texture ->
            ( { page | ship = setTextureOnce texture page.ship }, Cmd.none, env )

        GotShot texture ->
            ( { page | shots = setTextureOnce texture page.shots }, Cmd.none, env )

        Frame _ ->
            let
                newPage =
                    handleFrameUpdate page
            in
            if joined env.ws then
                ( newPage, movedShip newPage.ship, env )

            else
                ( newPage, Cmd.none, env )


handleWebSocketMessage : UserId -> E.Value -> Page -> Page
handleWebSocketMessage userId serialized page =
    case D.decodeValue (App.WebSocket.decodeMessage eventFromString) serialized of
        Err _ ->
            page

        Ok message ->
            case App.WebSocket.fromEvent message.event of
                RequestedState ->
                    case D.decodeValue (decodeState userId) message.payload of
                        Ok state ->
                            { page
                                | error = Nothing
                                , yarnballs = handleWebSocketYarnballUpdate state.enemies page.yarnballs
                                , shots = handleWebSocketMissileUpdate state.missiles page.shots
                                , otherShips = state.ships
                            }

                        Err error ->
                            { page
                                | error = Just (D.errorToString error)
                            }


handleWebSocketYarnballUpdate : List Yarnball -> Yarnballs -> Yarnballs
handleWebSocketYarnballUpdate serverYarnballs yarnballs =
    { yarnballs | entities = serverYarnballs }


handleWebSocketMissileUpdate : List Shot -> Shots -> Shots
handleWebSocketMissileUpdate serverShots shots =
    { shots | entities = serverShots }


type alias State =
    { enemies : List Yarnball
    , missiles : List Shot
    , ships : List OtherShip
    }


decodeState : UserId -> D.Decoder State
decodeState userId =
    D.succeed State
        |> DP.requiredAt [ "state", "enemies", "entities" ] (D.list decodeEnemy)
        |> DP.requiredAt [ "state", "missiles", "entities" ] (D.list decodeMissile)
        |> DP.requiredAt [ "state", "ships", "entities" ] (decodeShips userId)


decodeEnemy : D.Decoder Yarnball
decodeEnemy =
    D.succeed Yarnball
        |> DP.required "id" D.string
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.required "vel_x" D.float
        |> DP.required "vel_y" D.float


decodeMissile : D.Decoder Shot
decodeMissile =
    D.succeed Shot
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.required "vel_x" D.float
        |> DP.required "vel_y" D.float


decodeShips : UserId -> D.Decoder (List OtherShip)
decodeShips userId =
    D.map
        (\ships ->
            ships
                |> Dict.values
                |> List.filter (\ship -> ship.id /= userId)
        )
        (D.dict decodeShip)


decodeShip : D.Decoder OtherShip
decodeShip =
    D.succeed OtherShip
        |> DP.required "id" App.User.decodeId
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.required "angle" D.float
        |> DP.required "thrusting" D.bool


type SentEvent
    = FiredShot
    | ToggledPause
    | MovedShip


eventToString : SentEvent -> String
eventToString s =
    case s of
        FiredShot ->
            "fired_shot"

        ToggledPause ->
            "toggled_pause"

        MovedShip ->
            "moved_ship"


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
    { page | ship = (wrap << handleEntityPhysicsWithFriction) page.ship }


updateTick : Page -> Page
updateTick page =
    { page | tick = page.tick + 1 }


handleKeyPresses : Page -> Page
handleKeyPresses page =
    let
        ship =
            handleDirectionKeyPresses page.pressedKeys page.ship
    in
    -- TODO: improve interface / signature
    handleFiredShotKeyPresses { page | ship = ship }


handleFiredShotKeyPresses : Page -> Page
handleFiredShotKeyPresses page =
    page


togglePause : Cmd msg
togglePause =
    App.WebSocket.send
        eventToString
        topic
        ToggledPause
        (E.object [])


spawnShot : Ship -> Cmd msg
spawnShot ship =
    let
        ( x, y ) =
            initShotPosition ship

        ( velX, velY ) =
            fromPolar ( shotVel, ship.angle )
    in
    -- Shot x y velX velY tick shotLifespan
    App.WebSocket.send
        eventToString
        topic
        FiredShot
    <|
        E.object
            [ ( "x", E.float x )
            , ( "y", E.float y )
            , ( "vel_x", E.float velX )
            , ( "vel_y", E.float velY )
            ]


movedShip : Ship -> Cmd msg
movedShip ship =
    App.WebSocket.send
        eventToString
        topic
        MovedShip
    <|
        E.object
            [ ( "x", E.float ship.x )
            , ( "y", E.float ship.y )
            , ( "angle", E.float ship.angle )
            , ( "thrusting", E.bool ship.thrusting )
            ]


initShotPosition : Ship -> ( Float, Float )
initShotPosition ship =
    -- TODO: less magic constants - this is half of the ship text width / height
    let
        ( xTip, yTip ) =
            fromPolar ( 10, ship.angle )
    in
    ( ship.x + xTip + 45, ship.y + yTip + 45 )


shotVel : Float
shotVel =
    500.0


handleDirectionKeyPresses : List K.Key -> Ship -> Ship
handleDirectionKeyPresses keys ship =
    let
        { x, y } =
            KA.arrows keys

        thrusting =
            y > 0

        angle =
            if x /= 0 then
                degrees (toFloat x * turnSpeed)

            else
                0

        ( velX, velY ) =
            if thrusting then
                fromPolar ( acceleration, ship.angle )

            else
                ( 0, 0 )
    in
    { ship
        | angle = ship.angle + angle
        , velX = ship.velX + velX
        , velY = ship.velY + velY
        , thrusting = thrusting
    }


acceleration : Float
acceleration =
    0.5


turnSpeed : Float
turnSpeed =
    4.5


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
        , textures =
            [ loadYarnball toMsg
            , loadShip toMsg
            , loadShot toMsg
            ]
        }
        [ At.style "border" "10px solid rgba(0,0,0,0.1)" ]
    <|
        render page


render : Page -> List V.Renderable
render page =
    List.concat
        [ [ V.clear ( 0, 0 ) width height ]
        , renderYarnballs yarnballScale page
        , renderShots page
        , renderOtherShips page
        , [ renderShip page ]
        ]


loadYarnball : ToMsg msg -> VT.Source msg
loadYarnball toMsg =
    VT.loadFromImageUrl srcYarnball (toMsg << GotYarnball)


loadShip : ToMsg msg -> VT.Source msg
loadShip toMsg =
    VT.loadFromImageUrl srcShip (toMsg << GotShip)


loadShot : ToMsg msg -> VT.Source msg
loadShot toMsg =
    VT.loadFromImageUrl srcShot (toMsg << GotShot)


srcYarnball : String
srcYarnball =
    VPH.asset "/src/images/yarnballs/yarn_ball_256x256.png"


srcShip : String
srcShip =
    VPH.asset "/src/images/yarnballs/double_ship.png"


srcShot : String
srcShot =
    VPH.asset "/src/images/yarnballs/shot2.png"


width : number
width =
    640


height : number
height =
    480


renderYarnballs : Float -> Page -> List V.Renderable
renderYarnballs scale page =
    let
        rotation =
            degrees (page.tick * 3)
    in
    case page.yarnballs.texture of
        Nothing ->
            [ V.shapes [] [] ]

        Just texture ->
            page.yarnballs.entities
                |> List.map
                    (renderYarnball
                        { rotation = rotation, scale = scale }
                        texture
                    )


renderYarnball : { scale : Float, rotation : Float } -> VT.Texture -> Yarnball -> V.Renderable
renderYarnball { scale, rotation } texture yarnball =
    let
        dimensions =
            VT.dimensions texture

        centerX =
            dimensions.width * scale / 2 + yarnball.x

        centerY =
            dimensions.height * scale / 2 + yarnball.y
    in
    V.group
        []
        [ V.texture
            [ VA.transform
                [ VA.scale scale scale
                , VA.translate (centerX / scale) (centerY / scale)
                , VA.rotate rotation
                , VA.translate -(centerX / scale) -(centerY / scale)
                ]
            ]
            ( (centerX - dimensions.width / 2 * scale) / scale
            , (centerY - dimensions.height / 2 * scale) / scale
            )
            texture
        ]


renderShip : Page -> V.Renderable
renderShip page =
    case shipSprite page.ship of
        Nothing ->
            V.shapes [] []

        Just sprite ->
            let
                dimensions =
                    VT.dimensions sprite

                centerX =
                    dimensions.width / 2 + page.ship.x

                centerY =
                    dimensions.height / 2 + page.ship.y
            in
            V.group
                []
                [ renderShipRadius page
                , V.texture
                    [ VA.transform
                        [ VA.translate centerX centerY
                        , VA.rotate page.ship.angle
                        , VA.translate -centerX -centerY
                        ]
                    ]
                    ( page.ship.x, page.ship.y )
                    sprite
                ]


renderShipRadius : Page -> V.Renderable
renderShipRadius page =
    let
        -- TODO: magic const?
        dimensions =
            { width = 90, height = 90 }
    in
    V.shapes
        [ VS.fill Color.white
        , VS.stroke Color.black
        , VA.alpha 0.1
        ]
        [ V.circle ( page.ship.x + dimensions.width / 2, page.ship.y + dimensions.height / 2 ) 90 ]


shipSprite : Ship -> Maybe VT.Texture
shipSprite ship =
    ship.texture
        |> Maybe.map
            (\texture ->
                VT.sprite
                    { x =
                        if ship.thrusting then
                            90

                        else
                            0
                    , y = 0
                    , width = 90
                    , height = 90
                    }
                    texture
            )


renderOtherShips : Page -> List V.Renderable
renderOtherShips page =
    case page.ship.texture of
        Nothing ->
            [ V.shapes [] [] ]

        Just texture ->
            List.map (renderOtherShip texture) page.otherShips


renderOtherShip : VT.Texture -> OtherShip -> V.Renderable
renderOtherShip texture ship =
    let
        sprite =
            VT.sprite
                { x =
                    if ship.thrusting then
                        90

                    else
                        0
                , y = 0
                , width = 90
                , height = 90
                }
                texture

        dimensions =
            VT.dimensions sprite

        centerX =
            dimensions.width / 2 + ship.x

        centerY =
            dimensions.height / 2 + ship.y
    in
    V.group
        []
        [ V.texture
            [ VA.transform
                [ VA.translate centerX centerY
                , VA.rotate ship.angle
                , VA.translate -centerX -centerY
                ]
            ]
            ( ship.x, ship.y )
            sprite
        ]


renderShots : Page -> List V.Renderable
renderShots page =
    case page.shots.texture of
        Nothing ->
            [ V.shapes [] [] ]

        Just texture ->
            List.map
                (renderShot texture)
                page.shots.entities


renderShot : VT.Texture -> Shot -> V.Renderable
renderShot texture shot =
    V.texture [] ( shot.x, shot.y ) texture
