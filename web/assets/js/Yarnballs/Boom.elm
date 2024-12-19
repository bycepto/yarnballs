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
import Canvas.Settings as VS
import Canvas.Settings.Advanced as VA
import Canvas.Settings.Text as VW
import Canvas.Texture as VT
import Color
import Dict exposing (Dict)
import Json.Decode as D
import Json.Decode.Pipeline as DP



-- MODEL


type alias Booms =
    { texture : Maybe VT.Texture
    , entities : Dict String Boom
    }


type alias Boom =
    { id : String
    , x : Float
    , y : Float
    , size : Float
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
    "/assets/explosion_alpha.png"



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
        |> DP.required "size" D.float
        |> DP.hardcoded initTick



-- RENDER


render : Float -> Booms -> List V.Renderable
render tick booms =
    case booms.texture of
        Nothing ->
            []

        Just texture ->
            List.map
                (renderOneBoomWithPoint texture tick)
                (Dict.values booms.entities)


renderOneBoomWithPoint : VT.Texture -> Float -> Boom -> V.Renderable
renderOneBoomWithPoint texture tick boom =
    V.group
        [ VA.transform
            [ VA.translate
                ((boom.size - width) / 2)
                ((boom.size - height) / 2)
            ]
        ]
        [ renderOneBoom texture tick boom
        , renderScorePoint tick boom
        ]


renderOneBoom : VT.Texture -> Float -> Boom -> V.Renderable
renderOneBoom texture tick boom =
    V.texture
        []
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


renderScorePoint : Float -> Boom -> V.Renderable
renderScorePoint tick boom =
    V.text
        [ VW.align VW.Center
        , VW.baseLine VW.Middle
        , VS.stroke Color.green
        ]
        ( boom.x + width / 2
        , boom.y + height / 2 - min 20 (tick - boom.startTick)
        )
    <|
        "+1"


width : Float
width =
    128


height : Float
height =
    width
