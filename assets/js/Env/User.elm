module Env.User exposing
    ( User
    , UserId
    , decode
    , decodeId
    , encodeId
    , idFromString
    , idToString
    , name
    , viewIdenticon
    )

{-| This module exposes a struct that represents the signed-in user.
The user can be anonymous.
-}

import Color
import Html.Styled as H
import Identicon
import Json.Decode as D
import Json.Decode.Pipeline as DP
import Json.Encode as E



-- MODEL


type alias User =
    { id : UserId
    , displayName : String
    , accessToken : String
    }


type UserId
    = UserId String


idFromString : String -> UserId
idFromString id =
    UserId id


idToString : UserId -> String
idToString (UserId id) =
    id



-- DECODE / ENCODE


decode : D.Decoder User
decode =
    D.succeed User
        |> DP.requiredAt (userPath "id") decodeId
        |> DP.requiredAt (userPath "name") D.string
        |> DP.requiredAt [ "data", "token" ] D.string


userPath : String -> List String
userPath field =
    [ "data", "user", field ]


decodeId : D.Decoder UserId
decodeId =
    D.map idFromString D.string


encodeId : UserId -> E.Value
encodeId =
    E.string << idToString


name : User -> String
name user =
    user.displayName



-- VIEWS


viewIdenticon : String -> UserId -> H.Html msg
viewIdenticon size userId =
    idToString userId
        |> Identicon.custom Identicon.defaultHash (\_ -> Color.black) size
        |> H.fromUnstyled
