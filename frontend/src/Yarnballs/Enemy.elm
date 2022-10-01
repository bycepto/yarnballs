module Yarnballs.Enemy exposing
    ( Enemies
    , decode
    , height
    , init
    , loadBouncerTexture
    , loadRockTexture
    , render
    , width
    )

{-| This module renders enemies.
-}

import Canvas as V
import Canvas.Settings.Advanced as VA
import Canvas.Texture as VT
import Json.Decode as D
import Json.Decode.Pipeline as DP
import VitePluginHelper as VPH



-- MODEL


type alias Enemies =
    { bouncerTexture : Maybe VT.Texture
    , rockTexture : Maybe VT.Texture
    , entities : List Enemy
    , spawned : Int
    , destroyed : Int
    }


type Enemy
    = Bouncer EnemyData
    | Rock EnemyData


type alias EnemyData =
    { id : String
    , x : Float
    , y : Float
    , velX : Float
    , velY : Float
    }


init : Enemies
init =
    Enemies Nothing Nothing [] 0 0


loadBouncerTexture : (Maybe VT.Texture -> msg) -> VT.Source msg
loadBouncerTexture =
    VT.loadFromImageUrl (VPH.asset "/src/images/yarnballs/yarn_ball_256x256.png")


loadRockTexture : (Maybe VT.Texture -> msg) -> VT.Source msg
loadRockTexture =
    VT.loadFromImageUrl (VPH.asset "/src/images/yarnballs/asteroid_blue.png")


type alias EnemyTextures =
    { rock : VT.Texture, bouncer : VT.Texture }


getTextures : Enemies -> Maybe EnemyTextures
getTextures enemies =
    case ( enemies.rockTexture, enemies.bouncerTexture ) of
        ( Just rock, Just bouncer ) ->
            Just { rock = rock, bouncer = bouncer }

        _ ->
            Nothing



-- DECODE


decode : Enemies -> D.Decoder Enemies
decode enemies =
    D.map3
        (handleDecoded enemies)
        (D.field "spawned_count" D.int)
        (D.field "destroyed_count" D.int)
        (D.field "entities" <| D.list decodeEnemy)


handleDecoded : Enemies -> Int -> Int -> List Enemy -> Enemies
handleDecoded enemies spawned destroyed decoded =
    { enemies | entities = decoded, spawned = spawned, destroyed = destroyed }


decodeEnemy : D.Decoder Enemy
decodeEnemy =
    D.field "kind" D.string
        |> D.andThen decodeByKind


decodeByKind : String -> D.Decoder Enemy
decodeByKind kind =
    case kind of
        "bouncer" ->
            D.map Bouncer decodeEnemyData

        "rock" ->
            D.map Rock decodeEnemyData

        _ ->
            D.fail <| "unknown kind \"" ++ kind ++ "\""


decodeEnemyData : D.Decoder EnemyData
decodeEnemyData =
    D.succeed EnemyData
        |> DP.required "id" D.string
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.required "vel_x" D.float
        |> DP.required "vel_y" D.float



-- RENDER


render : Float -> Enemies -> List V.Renderable
render tick enemies =
    let
        rotation =
            degrees (tick * degreesPerTick)
    in
    case getTextures enemies of
        Nothing ->
            []

        Just textures ->
            enemies.entities |> List.map (renderOne rotation textures)


renderOne : Float -> EnemyTextures -> Enemy -> V.Renderable
renderOne rotation textures enemy =
    let
        centerX =
            (width enemy / 2) + getX enemy

        centerY =
            (height enemy / 2) + getY enemy
    in
    V.group
        []
        [ V.texture
            [ VA.transform
                [ VA.scale (scale enemy) (scale enemy)
                , VA.translate (centerX / scale enemy) (centerY / scale enemy)
                , VA.rotate rotation
                , VA.translate -(centerX / scale enemy) -(centerY / scale enemy)
                ]
            ]
            ( (centerX - width enemy / 2) / scale enemy
            , (centerY - height enemy / 2) / scale enemy
            )
            (getTexture textures enemy)
        ]


getX : Enemy -> Float
getX enemy =
    case enemy of
        Bouncer { x } ->
            x

        Rock { x } ->
            x


getY : Enemy -> Float
getY enemy =
    case enemy of
        Bouncer { y } ->
            y

        Rock { y } ->
            y


width : Enemy -> Float
width enemy =
    case enemy of
        Bouncer _ ->
            256 * scale enemy

        Rock _ ->
            90


height : Enemy -> Float
height enemy =
    case enemy of
        Bouncer _ ->
            width enemy

        Rock _ ->
            width enemy


scale : Enemy -> Float
scale enemy =
    case enemy of
        Bouncer _ ->
            0.3

        Rock _ ->
            1


getTexture : EnemyTextures -> Enemy -> VT.Texture
getTexture textures enemy =
    case enemy of
        Bouncer _ ->
            textures.bouncer

        Rock _ ->
            textures.rock


degreesPerTick : Float
degreesPerTick =
    3
