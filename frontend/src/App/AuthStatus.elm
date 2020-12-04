port module App.AuthStatus exposing
    ( AuthStatus(..)
    , Msg
    , emptySigninForm
    , headers
    , httpAnonymousSignIn
    , httpRefreshToken
    , init
    , signOut
    , toUser
    , update
    , viewLogin
    )

{-| This module manages authentication, including anonymous sessions
-}

import App
import App.ApiClient exposing (ApiClient)
import App.CommonElements
import App.RoutingKey exposing (RoutingKey)
import App.User exposing (User)
import App.WebSocket
import Html.Styled as H
import Html.Styled.Attributes as At
import Html.Styled.Events as Ev
import Http
import Url



-- PORTS


{-| Store a newly-obtained refresh token in local storage
-}
port storeRefreshToken : Maybe String -> Cmd msg


{-| Clear refresh token in local storage
-}
port clearRefreshToken : () -> Cmd msg



-- MODEL


type AuthStatus
    = Loading
    | SignedOut SignInForm
    | SignedIn User


type alias SignInForm =
    { username : String, password : String }


emptySigninForm : SignInForm
emptySigninForm =
    { username = "", password = "" }


toUser : AuthStatus -> Maybe User
toUser auth =
    case auth of
        Loading ->
            Nothing

        SignedOut _ ->
            Nothing

        SignedIn user ->
            Just user


headers : AuthStatus -> List Http.Header
headers auth =
    List.concat
        [ [ Http.header "Content-Type" "application/json" ]
        , case auth of
            Loading ->
                []

            SignedOut _ ->
                []

            SignedIn { accessToken } ->
                [ Http.header "Authorization" <| "Bearer " ++ accessToken
                ]
        ]


{-| If there is no refresh token the user is signed out. If there is a token,
set the authentication status to `loading` and attempt to exchange it for an
access token.
-}
init : ToMsg msg -> Maybe Url.Url -> String -> Maybe String -> ( AuthStatus, Cmd msg )
init toMsg redirect baseUrl refreshToken =
    case refreshToken of
        Nothing ->
            ( SignedOut emptySigninForm, Cmd.none )

        Just token ->
            ( Loading, httpRefreshToken toMsg redirect { token = token, baseUrl = baseUrl } )



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = SignIn (Maybe Url.Url)
    | SignOut
    | RecvCheckAuthStatusResponse (Maybe Url.Url) (Result Http.Error User)
    | RecvSignInResponse (Maybe Url.Url) (Result Http.Error User)
    | UpdateSignInForm SignInForm


update : ToMsg msg -> Msg -> RoutingKey -> ApiClient -> AuthStatus -> ( AuthStatus, Cmd msg )
update toMsg msg key api auth =
    case msg of
        SignIn redirect ->
            case auth of
                SignedIn _ ->
                    ( auth, Cmd.none )

                Loading ->
                    ( auth, Cmd.none )

                SignedOut form ->
                    ( auth, httpSignIn toMsg redirect form api )

        SignOut ->
            ( SignedOut emptySigninForm
            , Cmd.batch
                [ clearRefreshToken ()
                , App.WebSocket.disconnect
                ]
            )

        RecvCheckAuthStatusResponse redirect result ->
            updateAuthStatus key redirect result

        RecvSignInResponse redirect result ->
            updateAuthStatus key redirect result

        UpdateSignInForm form ->
            case auth of
                SignedIn _ ->
                    ( auth, Cmd.none )

                Loading ->
                    ( auth, Cmd.none )

                SignedOut _ ->
                    ( SignedOut form, Cmd.none )


signOut : ToMsg msg -> Cmd msg
signOut toMsg =
    App.run (toMsg SignOut)


{-| init auth per page
-}
updateAuthStatus : RoutingKey -> Maybe Url.Url -> Result Http.Error User -> ( AuthStatus, Cmd msg )
updateAuthStatus key redirect result =
    case result of
        Ok user ->
            ( SignedIn user
            , Cmd.batch
                [ storeRefreshToken (Just user.refreshToken)
                , App.WebSocket.connect user
                , redirect
                    |> Maybe.map (\url -> App.RoutingKey.pushUrl url key)
                    |> Maybe.withDefault (App.RoutingKey.visitHome key)
                ]
            )

        Err _ ->
            ( SignedOut emptySigninForm
            , Cmd.none
            )



-- HTTP


httpRefreshToken : ToMsg msg -> Maybe Url.Url -> { token : String, baseUrl : String } -> Cmd msg
httpRefreshToken toMsg redirect conf =
    App.ApiClient.refreshToken (toMsg << RecvCheckAuthStatusResponse redirect) conf


httpAnonymousSignIn : ToMsg msg -> Maybe Url.Url -> ApiClient -> Maybe String -> Cmd msg
httpAnonymousSignIn toMsg redirect api displayName =
    App.ApiClient.signInAnonymously (toMsg << RecvSignInResponse redirect) displayName api


httpSignIn : ToMsg msg -> Maybe Url.Url -> SignInForm -> ApiClient -> Cmd msg
httpSignIn toMsg redirect form api =
    App.ApiClient.signInAsUser (toMsg << RecvSignInResponse redirect) form api



-- VIEWS


viewLogin : (Msg -> msg) -> Maybe Url.Url -> AuthStatus -> H.Html msg
viewLogin toMsg redirect auth =
    H.div
        []
        [ case auth of
            SignedIn { username } ->
                H.text <| "Welcome " ++ username ++ "!"

            Loading ->
                viewLoading

            SignedOut form ->
                viewSignedOut toMsg redirect form
        ]


viewLoading : H.Html msg
viewLoading =
    H.div
        []
        [ App.CommonElements.loadingSpinner ]


viewSignedOut : (Msg -> msg) -> Maybe Url.Url -> SignInForm -> H.Html msg
viewSignedOut toMsg redirect form =
    H.div
        []
        [ viewSignInForm
            { onSubmit = toMsg (SignIn redirect)
            , onUsernameInput =
                \value -> toMsg <| UpdateSignInForm { form | username = value }
            , onPasswordInput =
                \value -> toMsg <| UpdateSignInForm { form | password = value }
            }
            form
        ]


type alias SignInFormToMsg msg =
    { onUsernameInput : String -> msg
    , onPasswordInput : String -> msg
    , onSubmit : msg
    }


viewSignInForm : SignInFormToMsg msg -> SignInForm -> H.Html msg
viewSignInForm toMsg form =
    H.div
        [ App.onEnter toMsg.onSubmit
        ]
        [ H.div [] [ H.text "username" ]
        , H.div []
            [ H.input
                [ At.type_ "input"
                , Ev.onInput toMsg.onUsernameInput
                , At.value form.username
                ]
                []
            ]
        , H.div [] [ H.text "password" ]
        , H.div []
            [ H.input
                [ At.type_ "password"
                , Ev.onInput toMsg.onPasswordInput
                , At.value form.password
                ]
                []
            ]
        , H.div []
            [ H.button
                [ Ev.onClick toMsg.onSubmit
                ]
                [ H.text "Sign in" ]
            ]
        ]
