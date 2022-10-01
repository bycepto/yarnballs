module Yarnballs.Missile exposing
    ( Missiles
    , decode
    , init
    , loadTexture
    , render
    )

{-| This module renders missiles fired by players.
-}

import Canvas as V
import Canvas.Settings.Advanced as VA
import Canvas.Texture as VT
import Json.Decode as D
import Json.Decode.Pipeline as DP
import VitePluginHelper as VPH



-- MODEL


type alias Missiles =
    { texture : Maybe VT.Texture
    , entities : List Missile
    }


type alias Missile =
    { x : Float
    , y : Float
    , velX : Float
    , velY : Float
    , dead : Bool
    }


init : Missiles
init =
    Missiles Nothing []


loadTexture : (Maybe VT.Texture -> msg) -> VT.Source msg
loadTexture =
    VT.loadFromImageUrl imageSource


imageSource : String
imageSource =
    VPH.asset "/src/images/yarnballs/shot2.png"



-- DECODE


decode : Missiles -> D.Decoder Missiles
decode missiles =
    D.map
        (handleDecoded missiles)
        (D.list decodeMissile)


handleDecoded : Missiles -> List Missile -> Missiles
handleDecoded missiles decoded =
    { missiles | entities = decoded }


decodeMissile : D.Decoder Missile
decodeMissile =
    D.succeed Missile
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.required "vel_x" D.float
        |> DP.required "vel_y" D.float
        |> DP.required "dead" D.bool



-- RENDER


render : Missiles -> List V.Renderable
render missiles =
    case missiles.texture of
        Nothing ->
            []

        Just texture ->
            List.map
                (renderOne texture)
                missiles.entities


renderOne : VT.Texture -> Missile -> V.Renderable
renderOne texture shot =
    V.texture
        [ VA.alpha <|
            if shot.dead then
                0.3

            else
                1
        ]
        ( shot.x, shot.y )
        texture
