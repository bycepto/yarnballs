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


{-| Store a newly-obtained access token in local storage
-}
port storeAccessToken : Maybe String -> Cmd msg


{-| Clear access token in local storage
-}
port clearAccessToken : () -> Cmd msg



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


{-| If there is no access token the user is signed out. If there is a token,
set the authentication status to `loading` and attempt to exchange it for an
access token.
-}
init : ToMsg msg -> String -> Maybe String -> ( Auth, Cmd msg )
init toMsg baseUrl accessToken =
    let
        client =
            initClient baseUrl
    in
    case accessToken of
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
            , fetchMe toMsg token
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
            , clearAccessToken ()
            )

        RecvTokenResponse result ->
            case result of
                Ok user ->
                    ( { auth | status = SignedIn user }
                    , storeAccessToken (Just user.accessToken)
                    )

                Err _ ->
                    ( { auth | status = SignedOut }
                    , clearAccessToken ()
                    )



-- HTTP


{-| Sign in by obtaining an access token
-}
getToken : ToMsg msg -> String -> Client -> Cmd msg
getToken toMsg displayName _ =
    Http.post
        { url = B.absolute [ "api", "tokens" ] []
        , body = getTokenBody displayName
        , expect = Http.expectJson (toMsg << RecvTokenResponse) Env.User.decode
        }


getTokenBody : String -> Http.Body
getTokenBody displayName =
    Http.jsonBody <|
        E.object <|
            [ ( "display_name", E.string displayName )
            ]


{-| Get user information with access token.
-}
fetchMe : ToMsg msg -> String -> Cmd msg
fetchMe toMsg accessToken =
    -- TODO: use Http.post
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ accessToken) ]
        , url = B.absolute [ "api", "tokens" ] []
        , body = Http.emptyBody
        , expect = Http.expectJson (toMsg << RecvTokenResponse) Env.User.decode
        , timeout = Nothing
        , tracker = Nothing
        }
