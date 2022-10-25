port module Env.Auth exposing
    ( Auth
    , Msg
    , Status(..)
    , getStatus
    , getToken
    , init
    , toUser
    , update
    )

{-| This module manages anonymous user authentication
-}

import Env.User exposing (User)
import Http
import Json.Encode as E
import Url.Builder as B



-- PORTS


{-| Store a newly-obtained refresh token in local storage
-}
port storeRefreshToken : Maybe String -> Cmd msg


{-| Clear refresh token in local storage
-}
port clearRefreshToken : () -> Cmd msg



-- MODEL


type alias Auth =
    { client : Client
    , status : Status
    }


type Client
    = Client { baseUrl : String }


type Status
    = Loading
    | SignedOut
    | SignedIn User


toUser : Auth -> Maybe User
toUser { status } =
    case status of
        Loading ->
            Nothing

        SignedOut ->
            Nothing

        SignedIn user ->
            Just user


getStatus : Auth -> Status
getStatus { status } =
    status


{-| If there is no refresh token the user is signed out. If there is a token,
set the authentication status to `loading` and attempt to exchange it for an
access token.
-}
init : ToMsg msg -> String -> Maybe String -> ( Auth, Cmd msg )
init toMsg baseUrl refreshToken =
    let
        client =
            initClient baseUrl
    in
    case refreshToken of
        Nothing ->
            ( { status = SignedOut
              , client = client
              }
            , Cmd.none
            )

        Just token ->
            ( { status = Loading
              , client = client
              }
            , renewToken toMsg token client
            )


initClient : String -> Client
initClient baseUrl =
    Client { baseUrl = baseUrl }



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = SignOut
    | RecvTokenResponse (Result Http.Error User)


update : Msg -> Auth -> ( Auth, Cmd msg )
update msg auth =
    case msg of
        SignOut ->
            ( { auth | status = SignedOut }
            , clearRefreshToken ()
            )

        RecvTokenResponse result ->
            case result of
                Ok user ->
                    ( { auth | status = SignedIn user }
                    , storeRefreshToken (Just user.refreshToken)
                    )

                Err _ ->
                    ( { auth | status = SignedOut }
                    , clearRefreshToken ()
                    )



-- HTTP


{-| Sign in by obtaining an access token
-}
getToken : ToMsg msg -> String -> Client -> Cmd msg
getToken toMsg displayName (Client { baseUrl }) =
    -- TODO: use Http.post
    Http.request
        { method = "POST"
        , headers = []
        , url = B.crossOrigin baseUrl [ "refresh-tokens" ] []
        , body = getTokenBody displayName
        , expect = Http.expectJson (toMsg << RecvTokenResponse) Env.User.decode
        , timeout = Nothing
        , tracker = Nothing
        }


getTokenBody : String -> Http.Body
getTokenBody displayName =
    Http.jsonBody <|
        E.object <|
            [ ( "display_name", E.string displayName )
            ]


{-| Exchange a refresh token for a new access token
-}
renewToken : ToMsg msg -> String -> Client -> Cmd msg
renewToken toMsg refreshToken (Client { baseUrl }) =
    -- TODO: use Http.post
    Http.request
        { method = "POST"
        , headers = []
        , url = B.crossOrigin baseUrl [ "access-tokens" ] []
        , body = renewTokenBody refreshToken
        , expect = Http.expectJson (toMsg << RecvTokenResponse) Env.User.decode
        , timeout = Nothing
        , tracker = Nothing
        }


renewTokenBody : String -> Http.Body
renewTokenBody refreshToken =
    Http.jsonBody <|
        E.object [ ( "refresh", E.string refreshToken ) ]
