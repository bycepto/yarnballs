module App exposing
    ( delay
    , exponentialBackoff
    , isMobileWidth
    , onEnter
    , run
    )

{-| This module contains helper functions that apply to the entire app
-}

import Html.Styled as H
import Html.Styled.Events as Ev
import Json.Decode as D
import Process
import Task



-- Constants


isMobileWidth : Float -> Bool
isMobileWidth width =
    width <= 900


{-| Exponentially back off up until 30 mins
-}
exponentialBackoff : Int -> Float
exponentialBackoff failCount =
    -- TODO: add max time
    Basics.min (toFloat (1000 * (2 ^ failCount))) 1800000



-- Key-press detection


onEnter : msg -> H.Attribute msg
onEnter msg =
    Ev.on "keydown" (D.andThen (enterDecoder msg) Ev.keyCode)


enterDecoder : msg -> Int -> D.Decoder msg
enterDecoder msg code =
    if code == 13 then
        D.succeed msg

    else
        D.fail ""



-- Msg Helpers


run : msg -> Cmd msg
run msg =
    Task.perform (always msg) (Task.succeed ())


delay : Float -> msg -> Cmd msg
delay time msg =
    Process.sleep time
        |> Task.andThen (always <| Task.succeed msg)
        |> Task.perform identity
