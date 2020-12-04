module App.ApiClient exposing
    ( ApiClient
    , init
    , refreshToken
    , signInAnonymously
    , signInAsUser
    )

{-| This module is responsible for communicating to server http API.
-}

import App.User exposing (User)
import Http
import Json.Encode as E
import Url.Builder as B



-- MODEL


type ApiClient
    = ApiClient { baseUrl : String }


type alias ToMsg a msg =
    Result Http.Error a -> msg


init : String -> ApiClient
init baseUrl =
    ApiClient { baseUrl = baseUrl }



-- UPDATE


type alias SignInForm =
    { username : String, password : String }


{-| Sign in as a user
-}
signInAsUser : ToMsg User msg -> SignInForm -> ApiClient -> Cmd msg
signInAsUser toMsg form api =
    signIn toMsg (signInAsUserBody form) api


signInAsUserBody : SignInForm -> Http.Body
signInAsUserBody form =
    Http.jsonBody <|
        E.object <|
            [ ( "username", E.string form.username )
            , ( "password", E.string form.password )
            ]


{-| Sign in anonymously
-}
signInAnonymously : ToMsg User msg -> Maybe String -> ApiClient -> Cmd msg
signInAnonymously toMsg displayName api =
    signIn toMsg (signInAnonymouslyBody displayName) api


signInAnonymouslyBody : Maybe String -> Http.Body
signInAnonymouslyBody displayName =
    Http.jsonBody <|
        E.object <|
            [ ( "display_name"
              , case displayName of
                    Nothing ->
                        E.null

                    Just name ->
                        E.string name
              )
            ]


{-| Sign in by obtaining an access token
-}
signIn : ToMsg User msg -> Http.Body -> ApiClient -> Cmd msg
signIn toMsg body (ApiClient api) =
    Http.request
        { method = "POST"
        , headers = []
        , url = B.crossOrigin api.baseUrl [ "refresh-tokens" ] []
        , body = body
        , expect = Http.expectJson toMsg App.User.decode
        , timeout = Nothing
        , tracker = Nothing
        }


{-| Exchange a refresh token for a new access token
-}
refreshToken : ToMsg User msg -> { baseUrl : String, token : String } -> Cmd msg
refreshToken toMsg conf =
    let
        body =
            [ ( "refresh", E.string conf.token ) ]
                |> E.object
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , headers = []
        , url = B.crossOrigin conf.baseUrl [ "access-tokens" ] []
        , body = body
        , expect = Http.expectJson toMsg App.User.decode
        , timeout = Nothing
        , tracker = Nothing
        }
