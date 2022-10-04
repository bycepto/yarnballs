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
import Round
import VitePluginHelper as VPH



-- MODEL


type alias Ships =
    { ship : UserShip
    , otherShips : List OtherShip
    , texture : Maybe VT.Texture
    }


init : Ships
init =
    { ship = UserShip Nothing 0 0 0 0 False 0 -fireShotCooldownTicks 0
    , otherShips = []
    , texture = Nothing
    }


type alias UserShip =
    { name : Maybe String
    , x : Float
    , y : Float
    , velX : Float
    , velY : Float
    , thrusting : Bool
    , angle : Float
    , lastFireTick : Float
    , health : Float
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


decode : UserId -> Ships -> D.Decoder Ships
decode userId ships =
    D.map2
        (handleDecoded ships)
        (decodeOtherShips userId)
        (decodePartialUserShip userId)


handleDecoded : Ships -> List OtherShip -> Maybe PartialUserShip -> Ships
handleDecoded ships otherShips partialUserShip =
    { ships
        | otherShips = otherShips
        , ship =
            case partialUserShip of
                Nothing ->
                    ships.ship

                Just { name, velX, velY, health } ->
                    let
                        ship =
                            ships.ship
                    in
                    { ship
                        | name = name
                        , velX = ship.velX + velX
                        , velY = ship.velY + velY
                        , health = health
                    }
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
    , velX : Float
    , velY : Float
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
        |> DP.required "vel_x" D.float
        |> DP.required "vel_y" D.float
        |> DP.required "health" D.float



-- UPDATE/WEBSOCKET


fireShot : App.WebSocket.Topic -> Float -> Ships -> ( Ships, Cmd msg )
fireShot topic tick ships =
    if (tick - ships.ship.lastFireTick) > fireShotCooldownTicks then
        ( { ships | ship = fireShotUpdateTick tick ships.ship }
        , fireShotSend topic ships
        )

    else
        ( ships, Cmd.none )


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
    500.0


move : App.WebSocket.Topic -> Ships -> Cmd msg
move topic ships =
    App.WebSocket.send
        eventToString
        topic
        MovedShip
    <|
        E.object
            [ ( "x", E.float ships.ship.x )
            , ( "y", E.float ships.ship.y )
            , ( "angle", E.float ships.ship.angle )
            , ( "thrusting", E.bool ships.ship.thrusting )
            ]


type SentEvent
    = FiredShot
    | MovedShip


eventToString : SentEvent -> String
eventToString s =
    case s of
        FiredShot ->
            "fired_shot"

        MovedShip ->
            "moved_ship"



-- UPDATE/KEYBOARD


handleKeyPresses : List K.Key -> Ships -> Ships
handleKeyPresses keys ships =
    { ships | ship = handleUserShipKeyPresses keys ships.ship }


handleUserShipKeyPresses : List K.Key -> UserShip -> UserShip
handleUserShipKeyPresses keys ship =
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


turnSpeed : Float
turnSpeed =
    4.5


acceleration : Float
acceleration =
    0.5



-- RENDER


render : Bool -> Ships -> List V.Renderable
render hurt ships =
    case ships.texture of
        Nothing ->
            []

        Just texture ->
            renderUserShip hurt texture ships.ship :: renderOtherShips texture ships.otherShips


width : Float
width =
    90


height : Float
height =
    width


renderUserShip : Bool -> VT.Texture -> UserShip -> V.Renderable
renderUserShip hurt texture ship =
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
        , renderUserHealth ship
        ]


renderUserHealth : UserShip -> V.Renderable
renderUserHealth ship =
    V.text
        [ VW.align VW.Center ]
        ( ship.x + width / 2, ship.y + height + 20 )
    <|
        if dead ship then
            "dead (fire to respawn)"

        else
            "shields: " ++ Round.round 0 ship.health ++ "%"


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
