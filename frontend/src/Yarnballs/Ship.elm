module Yarnballs.Ship exposing
    ( Ships
    , decode
    , fireShot
    , handleDecoded
    , handleKeyPresses
    , height
    , init
    , loadTexture
    , move
    , render
    , width
    )

{-| This module renders all spaceships and exposes controls for the user's spaceship.
-}

import App.User exposing (UserId)
import App.WebSocket
import Canvas as V
import Canvas.Settings as VS
import Canvas.Settings.Advanced as VA
import Canvas.Settings.Text as VW
import Canvas.Texture as VT
import Color
import Dict
import Json.Decode as D
import Json.Decode.Pipeline as DP
import Json.Encode as E
import Keyboard as K
import Keyboard.Arrows as KA
import VitePluginHelper as VPH



-- MODEL


type alias Ships =
    { ship : UserShip
    , otherShips : List OtherShip
    , texture : Maybe VT.Texture
    }


init : Ships
init =
    { ship = initShip
    , otherShips = []
    , texture = Nothing
    }


initShip : UserShip
initShip =
    UserShip
        Nothing
        0
        0
        0
        0
        0
        0
        False
        0
        -fireShotCooldownTicks
        -respawnDelay


type alias UserShip =
    { name : Maybe String
    , x : Float
    , y : Float
    , angle : Float
    , velX : Float
    , velY : Float
    , velAngle : Float
    , thrusting : Bool
    , health : Float

    -- effects
    , lastFireTick : Float
    , diedTick : Float
    }


type alias OtherShip =
    { id : UserId
    , name : Maybe String
    , x : Float
    , y : Float
    , angle : Float
    , thrusting : Bool
    , health : Float
    }


loadTexture : (Maybe VT.Texture -> msg) -> VT.Source msg
loadTexture =
    VT.loadFromImageUrl imageSource


imageSource : String
imageSource =
    VPH.asset "/src/images/yarnballs/double_ship.png"


dead : { a | health : Float } -> Bool
dead ship =
    ship.health <= 0



-- DECODE


decode : Float -> UserId -> Ships -> D.Decoder Ships
decode tick userId ships =
    D.map2
        (handleDecoded tick ships)
        (decodeOtherShips userId)
        (decodePartialUserShip userId)


handleDecoded : Float -> Ships -> List OtherShip -> Maybe PartialUserShip -> Ships
handleDecoded tick ships otherShips partialUserShip =
    { ships
        | otherShips = otherShips
        , ship =
            case partialUserShip of
                Nothing ->
                    ships.ship

                Just partial ->
                    fromPartialShip tick partial ships.ship
    }


fromPartialShip : Float -> PartialUserShip -> UserShip -> UserShip
fromPartialShip tick { name, x, y, angle, health } ship =
    { ship
        | name = name
        , x = x
        , y = y
        , angle = angle
        , health = health
        , diedTick =
            if dead { health = health } && not (dead ship) then
                tick

            else
                ship.diedTick
    }


decodeOtherShips : UserId -> D.Decoder (List OtherShip)
decodeOtherShips userId =
    D.map
        (\ships ->
            ships
                |> Dict.values
                |> List.filter (\ship -> ship.id /= userId)
        )
        (D.dict decodeOtherShip)


decodeOtherShip : D.Decoder OtherShip
decodeOtherShip =
    D.succeed OtherShip
        |> DP.required "id" App.User.decodeId
        |> DP.required "name" (D.nullable D.string)
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.required "angle" D.float
        |> DP.required "thrusting" D.bool
        |> DP.required "health" D.float


type alias PartialUserShip =
    { name : Maybe String
    , x : Float
    , y : Float
    , angle : Float
    , health : Float
    }


decodePartialUserShip : UserId -> D.Decoder (Maybe PartialUserShip)
decodePartialUserShip userId =
    D.map
        (\acc_by_id ->
            acc_by_id
                |> Dict.filter (\id _ -> id == App.User.idToString userId)
                |> Dict.values
                |> List.head
        )
        (D.dict decodePartialShip)


decodePartialShip : D.Decoder PartialUserShip
decodePartialShip =
    D.succeed PartialUserShip
        |> DP.required "name" (D.nullable D.string)
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.required "angle" D.float
        |> DP.required "health" D.float



-- UPDATE/WEBSOCKET


fireShot : App.WebSocket.Topic -> Float -> Ships -> ( Ships, Cmd msg )
fireShot topic tick ships =
    if fireShotAllowed tick ships.ship then
        ( { ships | ship = fireShotUpdateTick tick ships.ship }
        , fireShotSend topic ships
        )

    else
        ( ships, Cmd.none )


fireShotAllowed : Float -> UserShip -> Bool
fireShotAllowed tick ship =
    respawnAllowed tick ship && tick - ship.lastFireTick > fireShotCooldownTicks


respawnAllowed : Float -> UserShip -> Bool
respawnAllowed tick { diedTick } =
    tick - diedTick > respawnDelay


fireShotUpdateTick : Float -> UserShip -> UserShip
fireShotUpdateTick tick ship =
    { ship | lastFireTick = tick }


fireShotSend : App.WebSocket.Topic -> Ships -> Cmd msg
fireShotSend topic ships =
    let
        ( x, y ) =
            fireShotInitPosition ships.ship

        ( velX, velY ) =
            fromPolar ( fireShotVel, ships.ship.angle )
    in
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
            , ( "dead", E.bool <| dead ships.ship )
            ]


fireShotCooldownTicks : Float
fireShotCooldownTicks =
    -- TODO: move to server?
    8


fireShotInitPosition : UserShip -> ( Float, Float )
fireShotInitPosition ship =
    let
        ( xTipOffset, yTipOffset ) =
            fromPolar ( width / 2, ship.angle )
    in
    ( ship.x + xTipOffset + (width / 2), ship.y + yTipOffset + (height / 2) )


fireShotVel : Float
fireShotVel =
    -- TODO: move to server?
    500.0


respawnDelay : Float
respawnDelay =
    -- TODO: move to server?
    100


move : App.WebSocket.Topic -> Ships -> Cmd msg
move topic ships =
    Cmd.batch
        [ thrust topic ships
        , turn topic ships
        ]


thrust : App.WebSocket.Topic -> Ships -> Cmd msg
thrust topic ships =
    if ships.ship.thrusting then
        App.WebSocket.send
            eventToString
            topic
            ThrustedShip
        <|
            E.object
                [ ( "vel_x", E.float ships.ship.velX )
                , ( "vel_y", E.float ships.ship.velY )
                ]

    else
        Cmd.none


turn : App.WebSocket.Topic -> Ships -> Cmd msg
turn topic ships =
    App.WebSocket.send
        eventToString
        topic
        TurnedShip
    <|
        E.object
            [ ( "vel_angle", E.float ships.ship.velAngle )
            ]


type SentEvent
    = FiredShot
    | ThrustedShip
    | TurnedShip


eventToString : SentEvent -> String
eventToString s =
    case s of
        FiredShot ->
            "fired_shot"

        ThrustedShip ->
            "thrusted_ship"

        TurnedShip ->
            "turned_ship"



-- UPDATE/KEYBOARD


handleKeyPresses : List K.Key -> Ships -> Ships
handleKeyPresses keys ships =
    { ships | ship = handleUserShipKeyPresses keys ships.ship }


handleUserShipKeyPresses : List K.Key -> UserShip -> UserShip
handleUserShipKeyPresses keys ship =
    let
        { x, y } =
            KA.arrows keys

        velAngle =
            if x /= 0 then
                degrees (toFloat x * turnSpeed)

            else
                0

        thrusting =
            y > 0

        ( velX, velY ) =
            if thrusting then
                fromPolar ( acceleration, ship.angle )

            else
                ( ship.velX, ship.velY )
    in
    { ship
        | velAngle = velAngle
        , velX = velX
        , velY = velY
        , thrusting = thrusting
    }


turnSpeed : Float
turnSpeed =
    -- TODO: move to server?
    18000


acceleration : Float
acceleration =
    -- TODO: move to server?
    20.0



-- RENDER


render : Float -> Bool -> Ships -> List V.Renderable
render tick hurt ships =
    case ships.texture of
        Nothing ->
            []

        Just texture ->
            renderUserShip tick hurt texture ships.ship :: renderOtherShips texture ships.otherShips


width : Float
width =
    90


height : Float
height =
    width


renderUserShip : Float -> Bool -> VT.Texture -> UserShip -> V.Renderable
renderUserShip tick hurt texture ship =
    let
        sprite =
            shipSprite texture ship

        ( centerX, centerY ) =
            center ship
    in
    V.group
        []
        [ renderShipRadius hurt ship
        , V.texture
            [ VA.transform
                [ VA.translate centerX centerY
                , VA.rotate ship.angle
                , VA.translate -centerX -centerY
                ]
            , VA.alpha <|
                if dead ship then
                    0.3

                else
                    1
            ]
            ( ship.x, ship.y )
            sprite
        , renderDisplayName ship
        , renderUserHealth tick ship
        ]


renderUserHealth : Float -> UserShip -> V.Renderable
renderUserHealth tick ship =
    V.group
        []
        [ V.shapes
            [ VS.fill Color.white
            , VS.stroke Color.black
            ]
            [ V.rect ( ship.x, ship.y + height + 20 ) width 5
            ]
        , V.shapes
            [ VS.fill <|
                if ship.health < 25 then
                    Color.red

                else
                    Color.green
            ]
            [ V.rect
                ( ship.x, ship.y + height + 20 )
                (if dead ship then
                    0

                 else
                    width * ship.health / 100
                )
                5
            ]
        , V.text
            [ VW.align VW.Center ]
            ( ship.x + width / 2, ship.y + height + 40 )
          <|
            if dead ship && respawnAllowed tick ship then
                "(fire to respawn)"

            else
                ""
        ]


renderDisplayName : { a | name : Maybe String, x : Float, y : Float } -> V.Renderable
renderDisplayName ship =
    V.text
        [ VW.align VW.Center
        , VW.maxWidth width
        ]
        ( ship.x + width / 2, ship.y + height + 5 )
    <|
        Maybe.withDefault "???" ship.name


renderOtherShips : VT.Texture -> List OtherShip -> List V.Renderable
renderOtherShips sprite ships =
    List.map (renderOtherShip sprite) ships


renderOtherShip : VT.Texture -> OtherShip -> V.Renderable
renderOtherShip texture ship =
    let
        sprite =
            shipSprite texture ship

        ( centerX, centerY ) =
            center ship
    in
    V.group
        []
        [ V.texture
            [ VA.transform
                [ VA.translate centerX centerY
                , VA.rotate ship.angle
                , VA.translate -centerX -centerY
                ]
            , VA.alpha <|
                if dead ship then
                    0.3

                else
                    1
            ]
            ( ship.x, ship.y )
            sprite
        , renderDisplayName ship
        ]


shipSprite : VT.Texture -> { a | thrusting : Bool } -> VT.Texture
shipSprite texture ship =
    VT.sprite
        { x =
            if ship.thrusting then
                width

            else
                0
        , y = 0
        , width = width
        , height = height
        }
        texture


renderShipRadius : Bool -> UserShip -> V.Renderable
renderShipRadius hurt ship =
    V.shapes
        [ if hurt then
            VS.fill Color.red

          else
            VS.fill Color.white
        , VS.stroke Color.black
        , VA.alpha 0.1
        ]
        [ V.circle (center ship) width ]


center : { a | x : Float, y : Float } -> ( Float, Float )
center ship =
    ( ship.x + width / 2, ship.y + height / 2 )
