module App.User exposing
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
import Json.Encode as E



-- MODEL


type alias User =
    { id : UserId
    , username : String
    , displayName : Maybe String
    , anonymous : Bool

    {- TODO: how insecure is it to hold tokens in the model like this?
       Currently the app does not hold any sensitive information so this is not
       a high priority to figure out.
    -}
    , refreshToken : String
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
    D.map6
        User
        (atUserPath "id" decodeId)
        (atUserPath "username" D.string)
        (atUserPath "display_name" <| D.nullable D.string)
        (atUserPath "is_anonymous" D.bool)
        (D.at [ "data", "refresh" ] D.string)
        (D.at [ "data", "access" ] D.string)


atUserPath : String -> D.Decoder a -> D.Decoder a
atUserPath field =
    D.at [ "data", "user", field ]


decodeId : D.Decoder UserId
decodeId =
    D.map idFromString D.string


encodeId : UserId -> E.Value
encodeId =
    E.string << idToString


name : User -> String
name user =
    if user.anonymous then
        Maybe.withDefault user.username user.displayName

    else
        user.username



-- VIEWS


viewIdenticon : String -> UserId -> H.Html msg
viewIdenticon size userId =
    idToString userId
        |> Identicon.custom Identicon.defaultHash (\_ -> Color.black) size
        |> H.fromUnstyled
