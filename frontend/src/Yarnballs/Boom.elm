module Yarnballs.Boom exposing
    ( Booms
    , decode
    , height
    , init
    , loadTexture
    , render
    , width
    )

{-| This module renders booms.
-}

import Canvas as V
import Canvas.Settings.Advanced as VA
import Canvas.Texture as VT
import Dict exposing (Dict)
import Json.Decode as D
import Json.Decode.Pipeline as DP
import VitePluginHelper as VPH
import Yarnballs.Enemy



-- MODEL


type alias Booms =
    { texture : Maybe VT.Texture
    , entities : Dict String Boom
    }


type alias Boom =
    { id : String
    , x : Float
    , y : Float
    , startTick : Float
    }


init : Booms
init =
    Booms Nothing Dict.empty


loadTexture : (Maybe VT.Texture -> msg) -> VT.Source msg
loadTexture =
    VT.loadFromImageUrl imageSource


imageSource : String
imageSource =
    VPH.asset "/src/images/yarnballs/explosion_alpha.png"



-- DECODE


type alias Decoded =
    Dict String Boom


decode : Float -> Booms -> D.Decoder Booms
decode initTick booms =
    D.map
        (\serverBooms ->
            serverBooms
                |> List.map (\boom -> ( boom.id, boom ))
                |> Dict.fromList
                |> handleDecoded booms
        )
        (D.list <| decodeBoom initTick)


handleDecoded : Booms -> Decoded -> Booms
handleDecoded booms serverBooms =
    { booms
        | entities =
            Dict.merge
                (\id serverBoom result -> Dict.insert id serverBoom result)
                (\id _ clientBoom result -> Dict.insert id clientBoom result)
                (\_ _ result -> result)
                serverBooms
                booms.entities
                Dict.empty
    }


decodeBoom : Float -> D.Decoder Boom
decodeBoom initTick =
    D.succeed Boom
        |> DP.required "id" D.string
        |> DP.required "x" D.float
        |> DP.required "y" D.float
        |> DP.hardcoded initTick



-- RENDER


render : Float -> Booms -> List V.Renderable
render tick booms =
    case booms.texture of
        Nothing ->
            []

        Just texture ->
            List.map (renderOneBoom texture tick) (Dict.values booms.entities)


renderOneBoom : VT.Texture -> Float -> Boom -> V.Renderable
renderOneBoom texture tick boom =
    V.texture
        [ VA.transform
            [ VA.translate
                -- TODO: since other entities can explose, how can this method
                -- take the exploding entity's width and height?
                ((Yarnballs.Enemy.width - width) / 2)
                ((Yarnballs.Enemy.height - height) / 2)
            ]
        ]
        ( boom.x, boom.y )
        (boomSprite texture tick boom)


boomSprite : VT.Texture -> Float -> Boom -> VT.Texture
boomSprite texture tick boom =
    VT.sprite
        { x = max 0 (tick - boom.startTick) * width
        , y = 0
        , width = width
        , height = height
        }
        texture


width : Float
width =
    128


height : Float
height =
    width
