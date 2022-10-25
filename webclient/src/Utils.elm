module Utils exposing (..)

{-| This module contains common elements, styles, functions that don't quite
fit anywhere else at the moment.
-}

-- TODO: should anything here be part of another logical module?

import Color
import Css as C
import Css.Animations as An
import Html.Styled as H
import Html.Styled.Attributes as At



-- Color


{-| Convert elm-color value to be compatible with elm-css.

Note that hue is given as a percentage but elm-css expects it to be in degrees:
<https://github.com/avh4/elm-color/issues/19>

-}
fromColor : Color.Color -> C.Color
fromColor color =
    let
        { hue, saturation, lightness, alpha } =
            Color.toHsla color
    in
    C.hsla (hue * 360.0) saturation lightness alpha


loadingSpinner : Color.Color -> H.Html msg
loadingSpinner color =
    H.div
        [ At.css
            -- https://loading.io/css/
            [ C.after
                [ C.property "content" "\" \""
                , C.display C.block
                , C.width (C.px 64)
                , C.height (C.px 64)
                , C.margin (C.px 8)
                , C.borderRadius (C.pct 50)
                , C.border3 (C.px 6) C.solid (fromColor color)
                , C.borderColor4
                    (fromColor color)
                    C.transparent
                    (fromColor color)
                    C.transparent
                , C.animationName <|
                    An.keyframes
                        [ ( 0, [ An.property "transform" "rotate(0deg)" ] )
                        , ( 100, [ An.property "transform" "rotate(360deg)" ] )
                        ]
                , C.animationDuration (C.sec 1.2)
                , C.property "animation-timing-function" "linear"
                , C.property "animation-iteration-count" "infinite"
                ]
            , C.display C.inlineBlock
            , C.width (C.px 80)
            , C.height (C.px 80)
            ]
        ]
        []
