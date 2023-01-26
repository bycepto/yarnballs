module Yarnballs.Game exposing
    ( Game
    , Msg
    , decode
    , height
    , init
    , subscriptions
    , update
    , view
    , width
    )

{-| Represents the game for a Yarnballs room
-}

import Browser.Events as BE
import Canvas as V
import Canvas.Settings as VS
import Canvas.Settings.Advanced as VA
import Canvas.Settings.Text as VW
import Canvas.Texture as VT
import Color
import Env.User exposing (UserId)
import Html.Styled as H
import Json.Decode as D
import Json.Decode.Pipeline as DP
import Keyboard as K
import VitePluginHelper as VPH
import WebSocket
import Yarnballs.Boom exposing (Booms)
import Yarnballs.Enemy exposing (Enemies)
import Yarnballs.Missile exposing (Missiles)
import Yarnballs.Ship exposing (Ships)



-- MODEL


type alias Game =
    { -- state
      tick : Float
    , pressedKeys : List K.Key

    -- entities
    , ships : Ships
    , enemies : Enemies
    , missiles : Missiles
    , booms : Booms

    -- assets
    , bgTexture : Maybe VT.Texture
    , debrisTexture : Maybe VT.Texture

    -- stats
    , score : Int
    , level : Level
    , startLevelScore : Int
    , nextLevelScore : Maybe Int

    -- effects
    , shakeFor : Int
    }


type Level
    = LevelUp Int Float
    | LevelDown Int Float


levelNumber : Level -> Int
levelNumber level =
    case level of
        LevelUp n _ ->
            n

        LevelDown n _ ->
            n


levelTick : Level -> Float
levelTick level =
    case level of
        LevelUp _ tick ->
            tick

        LevelDown _ tick ->
            tick


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


init : Game
init =
    { tick = 0
    , pressedKeys = []
    , ships = Yarnballs.Ship.init
    , enemies = Yarnballs.Enemy.init
    , missiles = Yarnballs.Missile.init
    , booms = Yarnballs.Boom.init
    , bgTexture = Nothing
    , debrisTexture = Nothing
    , score = 0
    , level = LevelUp 0 0
    , startLevelScore = 0
    , nextLevelScore = Nothing
    , shakeFor = 0
    }


shakeTicks : Int
shakeTicks =
    30



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotKeyPress K.Msg
    | GotBouncer (Maybe VT.Texture)
    | GotRock (Maybe VT.Texture)
    | GotShip (Maybe VT.Texture)
    | GotMissile (Maybe VT.Texture)
    | GotBoom (Maybe VT.Texture)
    | GotBackground (Maybe VT.Texture)
    | GotDebris (Maybe VT.Texture)
    | Frame Float


update : Msg -> WebSocket.Topic -> Game -> ( Game, Cmd msg )
update msg topic game =
    case msg of
        GotKeyPress keyMsg ->
            ( { game | pressedKeys = K.update keyMsg game.pressedKeys }, Cmd.none )

        GotBouncer texture ->
            let
                enemies =
                    game.enemies
            in
            ( { game | enemies = { enemies | bouncerTexture = texture } }
            , Cmd.none
            )

        GotRock texture ->
            let
                enemies =
                    game.enemies
            in
            ( { game | enemies = { enemies | rockTexture = texture } }
            , Cmd.none
            )

        GotShip texture ->
            ( { game | ships = setTextureOnce texture game.ships }
            , Cmd.none
            )

        GotMissile texture ->
            ( { game | missiles = setTextureOnce texture game.missiles }, Cmd.none )

        GotBoom texture ->
            ( { game | booms = setTextureOnce texture game.booms }, Cmd.none )

        GotBackground texture ->
            ( case game.bgTexture of
                Nothing ->
                    { game | bgTexture = texture }

                Just _ ->
                    game
            , Cmd.none
            )

        GotDebris texture ->
            ( case game.debrisTexture of
                Nothing ->
                    { game | debrisTexture = texture }

                Just _ ->
                    game
            , Cmd.none
            )

        Frame _ ->
            let
                newGame =
                    handleFrameUpdate game

                ( newShips, cmdShips ) =
                    Yarnballs.Ship.update newGame topic newGame.ships
            in
            ( { newGame | ships = newShips }
            , cmdShips
            )


decode : UserId -> Game -> D.Decoder Game
decode userId game =
    D.map
        (handleDecoded game)
        (decodeState userId game)


handleDecoded : Game -> State -> Game
handleDecoded game state =
    { game
        | enemies = state.enemies
        , missiles = state.missiles
        , booms = state.booms
        , ships = state.ships
        , score = state.score
        , startLevelScore = state.startLevelScore
        , nextLevelScore = state.nextLevelScore
        , level =
            if state.level < levelNumber game.level then
                LevelDown state.level game.tick

            else if state.level > levelNumber game.level then
                LevelUp state.level game.tick

            else
                game.level
        , shakeFor =
            if state.ships.ship.health < game.ships.ship.health then
                shakeTicks

            else
                game.shakeFor
    }


type alias State =
    -- TODO: is this struct superfluous?
    { enemies : Enemies
    , missiles : Missiles
    , ships : Ships
    , booms : Booms
    , score : Int
    , level : Int
    , startLevelScore : Int
    , nextLevelScore : Maybe Int
    }


decodeState : UserId -> Game -> D.Decoder State
decodeState userId game =
    D.succeed State
        |> DP.requiredAt [ "state", "enemies" ] (Yarnballs.Enemy.decode game.enemies)
        |> DP.requiredAt [ "state", "missiles", "entities" ] (Yarnballs.Missile.decode game.missiles)
        |> DP.requiredAt [ "state", "ships", "entities" ] (Yarnballs.Ship.decode game.tick userId game.ships)
        |> DP.requiredAt [ "state", "enemies", "explosions", "entities" ] (Yarnballs.Boom.decode game.tick game.booms)
        |> DP.requiredAt [ "state", "score" ] D.int
        |> DP.requiredAt [ "state", "level" ] D.int
        |> DP.requiredAt [ "state", "start_level_score" ] D.int
        |> DP.requiredAt [ "state", "next_level_score" ] (D.nullable D.int)


handleFrameUpdate : Game -> Game
handleFrameUpdate game =
    game
        |> handleKeyPresses
        |> updateTick


updateTick : Game -> Game
updateTick game =
    { game
        | tick = game.tick + 1
        , shakeFor = max 0 (game.shakeFor - 1)
    }


handleKeyPresses : Game -> Game
handleKeyPresses game =
    { game
        | ships = Yarnballs.Ship.handleKeyPresses game.pressedKeys game.ships
    }



-- SUBSCRIPTIONS


subscriptions : ToMsg msg -> Sub msg
subscriptions toMsg =
    Sub.batch
        [ BE.onAnimationFrameDelta (toMsg << Frame)
        , keyboardSubscriptions toMsg
        ]


keyboardSubscriptions : ToMsg msg -> Sub msg
keyboardSubscriptions toMsg =
    -- Note that arrow keys are not triggered for onkeypress
    -- https://stackoverflow.com/questions/5597060/detecting-arrow-key-presses-in-javascript
    Sub.map (toMsg << GotKeyPress) K.subscriptions



-- VIEWS


view : ToMsg msg -> Game -> H.Html msg
view toMsg game =
    H.fromUnstyled <|
        V.toHtmlWith
            { width = width
            , height = height
            , textures = loadTextures toMsg
            }
            []
        <|
            render game


loadTextures : ToMsg msg -> List (VT.Source msg)
loadTextures toMsg =
    [ Yarnballs.Enemy.loadBouncerTexture (toMsg << GotBouncer)
    , Yarnballs.Enemy.loadRockTexture (toMsg << GotRock)
    , Yarnballs.Ship.loadTexture (toMsg << GotShip)
    , Yarnballs.Missile.loadTexture (toMsg << GotMissile)
    , Yarnballs.Boom.loadTexture (toMsg << GotBoom)
    , VT.loadFromImageUrl
        (VPH.asset "/src/images/yarnballs/debris2_blue.png")
        (toMsg << GotDebris)
    ]


render : Game -> List V.Renderable
render game =
    List.concat
        [ [ V.clear ( 0, 0 ) width height ]
        , renderBackground game.bgTexture
        , Yarnballs.Enemy.render game.tick game.enemies
        , Yarnballs.Missile.render game.missiles
        , Yarnballs.Ship.render game.tick (game.shakeFor > 0) game.ships
        , Yarnballs.Boom.render game.tick game.booms
        , renderDebris game.tick game.debrisTexture
        , renderLevel game.tick game.level
        , renderStats game
        , renderProgressBar game
        ]


renderBackground : Maybe VT.Texture -> List V.Renderable
renderBackground bgTexture =
    case bgTexture of
        Nothing ->
            []

        Just bg ->
            [ V.texture
                []
                ( 0, 0 )
                bg
            ]


renderDebris : Float -> Maybe VT.Texture -> List V.Renderable
renderDebris tick debrisTexture =
    case debrisTexture of
        Nothing ->
            []

        Just debris ->
            let
                x =
                    toFloat <| modBy width (round tick)
            in
            [ V.texture
                []
                ( x, 0 )
                debris
            , V.texture
                []
                ( x - width, 0 )
                debris
            ]


renderStats : Game -> List V.Renderable
renderStats game =
    [ V.text
        [ VW.align VW.Left
        , VW.baseLine VW.Top
        , VS.fill Color.darkGreen
        , VW.font { size = 18, family = "san-serif" }
        ]
        ( 5, 5 )
        ("score: " ++ String.fromInt game.score)
    ]


renderLevel : Float -> Level -> List V.Renderable
renderLevel tick level =
    let
        alpha =
            max 0 (100 - (tick - levelTick level)) / 100

        color =
            case level of
                LevelUp _ _ ->
                    Color.darkGreen

                LevelDown _ _ ->
                    Color.red
    in
    if alpha > 0 then
        [ V.text
            [ VW.align VW.Center
            , VW.baseLine VW.Middle
            , VS.fill color
            , VW.font { size = 144, family = "san-serif" }
            , VA.alpha alpha
            ]
            ( width / 2, height / 2 )
            ("Level " ++ String.fromInt (levelNumber level))
        ]

    else
        []


renderProgressBar : Game -> List V.Renderable
renderProgressBar game =
    case game.nextLevelScore of
        Nothing ->
            []

        Just score ->
            let
                needScore =
                    toFloat (score - game.startLevelScore)

                currentScore =
                    toFloat (game.score - game.startLevelScore)

                pct =
                    currentScore / needScore
            in
            [ V.shapes
                [ VS.fill Color.lightGray
                ]
                [ V.rect
                    ( width - progressBarWidth - 5, 5 )
                    progressBarWidth
                    progressBarHeight
                ]
            , V.shapes
                [ VS.fill Color.darkGray
                ]
                [ V.rect
                    ( width - progressBarWidth - 5, 5 )
                    (progressBarWidth * pct)
                    progressBarHeight
                ]
            , V.text
                [ VS.fill Color.darkGreen
                , VW.font { size = 18, family = "san-serif" }
                , VW.align VW.Center
                ]
                ( width - (progressBarWidth / 2) - 5, 20 )
                ("Level " ++ String.fromInt (levelNumber game.level))
            ]


progressBarWidth : number
progressBarWidth =
    150


progressBarHeight : number
progressBarHeight =
    20


width : number
width =
    640


height : number
height =
    480
