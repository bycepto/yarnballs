module Yarnballs.Enemy exposing
    ( Enemies
    , decode
    , height
    , init
    , loadTexture
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
    { texture : Maybe VT.Texture
    , entities : List Enemy
    }


type alias Enemy =
    { id : String
    , x : Float
    , y : Float
    , velX : Float
    , velY : Float
    }


init : Enemies
init =
    Enemies Nothing []


loadTexture : (Maybe VT.Texture -> msg) -> VT.Source msg
loadTexture =
    VT.loadFromImageUrl imageSource


imageSource : String
imageSource =
    VPH.asset "/src/images/yarnballs/yarn_ball_256x256.png"



-- DECODE


decode : Enemies -> D.Decoder Enemies
decode missiles =
    D.map
        (handleDecoded missiles)
        (D.list decodeEnemy)


handleDecoded : Enemies -> List Enemy -> Enemies
handleDecoded enemies decoded =
    { enemies | entities = decoded }


decodeEnemy : D.Decoder Enemy
decodeEnemy =
    D.succeed Enemy
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
    case enemies.texture of
        Nothing ->
            []

        Just texture ->
            enemies.entities |> List.map (renderOne rotation texture)


renderOne : Float -> VT.Texture -> Enemy -> V.Renderable
renderOne rotation texture enemy =
    let
        centerX =
            width / 2 + enemy.x

        centerY =
            height / 2 + enemy.y
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
            ( (centerX - width / 2) / scale
            , (centerY - height / 2) / scale
            )
            texture
        ]


width : Float
width =
    256 * scale


height : Float
height =
    width


scale : Float
scale =
    0.3


degreesPerTick : Float
degreesPerTick =
    3
