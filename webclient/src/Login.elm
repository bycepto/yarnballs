port module Login exposing
    ( Login
    , Msg
    , init
    , subscriptions
    , update
    , view
    )

import Color
import Css as C
import Env exposing (Env)
import Env.Auth
import Html.Styled as H
import Html.Styled.Attributes as At
import Html.Styled.Events as Ev
import Keyboard as K
import Utils



-- PORTS


{-| Request display name from local storage
-}
port getDisplayName : () -> Cmd msg


{-| Receive display name from local storage
-}
port displayNameReceiver : (Maybe String -> msg) -> Sub msg


{-| Set display name in local storage
-}
port setDisplayName : String -> Cmd msg



-- MODEL


type alias Login =
    { displayName : String
    }


init : ( Login, Cmd msg )
init =
    ( { displayName = "" }
    , getDisplayName ()
    )



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotAuthMsg Env.Auth.Msg
    | GotDisplayName (Maybe String)
    | UpdateDisplayName String
    | SubmitDisplayName
    | GotKeyDown K.RawKey



-- | Redirect


update : Env -> ToMsg msg -> Msg -> Login -> ( Login, Cmd msg, Env )
update env toMsg msg login =
    case msg of
        GotAuthMsg subMsg ->
            let
                ( newAuth, cmd ) =
                    Env.Auth.update subMsg env.auth
            in
            ( login
            , cmd
            , { env | auth = newAuth }
            )

        GotDisplayName displayName ->
            ( { login | displayName = Maybe.withDefault "" displayName }
            , Cmd.none
            , env
            )

        UpdateDisplayName value ->
            ( { login | displayName = value }
            , Cmd.none
            , env
            )

        SubmitDisplayName ->
            handleSubmitDisplayName env toMsg login

        GotKeyDown rawKey ->
            case K.whitespaceKey rawKey of
                Just K.Enter ->
                    handleSubmitDisplayName env toMsg login

                _ ->
                    ( login, Cmd.none, env )


handleSubmitDisplayName : Env -> ToMsg msg -> Login -> ( Login, Cmd msg, Env )
handleSubmitDisplayName env toMsg login =
    ( login
    , case Env.Auth.toUser env.auth of
        Nothing ->
            Cmd.batch
                [ setDisplayName login.displayName
                , Env.Auth.getToken
                    (toMsg << GotAuthMsg)
                    login.displayName
                    env.auth.client
                ]

        Just _ ->
            Cmd.none
    , env
    )



-- SUBSCRIPTIONS


subscriptions : ToMsg msg -> Sub msg
subscriptions toMsg =
    -- TODO: do not listen when logged in?
    Sub.batch
        [ displayNameReceiver (toMsg << GotDisplayName)
        , K.downs (toMsg << GotKeyDown)
        ]



-- VIEWS


view : ToMsg msg -> Color.Color -> Login -> { title : String, content : H.Html msg }
view toMsg fontColor login =
    { title = "Login"
    , content = viewBody toMsg fontColor login
    }


viewBody : ToMsg msg -> Color.Color -> Login -> H.Html msg
viewBody toMsg fontColor login =
    H.div
        [ At.css
            [ -- flex
              C.displayFlex
            , C.flexDirection C.column
            , C.justifyContent C.center
            , C.alignItems C.center

            -- font color
            , C.color (Utils.fromColor fontColor)
            ]
        , At.css
            [ C.height (C.vh 80) ]
        ]
        [ viewContainer toMsg login
        ]


viewContainer : ToMsg msg -> Login -> H.Html msg
viewContainer toMsg login =
    H.div
        [ At.css
            [ C.displayFlex
            , C.flexDirection C.column
            , C.property "row-gap" "5C.px"
            ]
        , At.css
            [ C.margin2 (C.px 0) C.auto
            , C.width (C.px 300)
            ]
        , At.css
            [ C.textAlign C.center ]
        ]
    <|
        [ H.h1 [] [ H.text "Yarnballs" ]
        , viewAnonymousLogin toMsg login
        ]


viewAnonymousLogin : ToMsg msg -> Login -> H.Html msg
viewAnonymousLogin toMsg login =
    viewWhatsYourName toMsg login


viewWhatsYourName : (Msg -> msg) -> Login -> H.Html msg
viewWhatsYourName toMsg login =
    H.div
        []
        [ viewSetDisplayName
            { onUpdate = toMsg << UpdateDisplayName
            , onSubmit = toMsg SubmitDisplayName
            }
            login.displayName
        ]


type alias DisplayNameFormToMsg msg =
    { onUpdate : String -> msg
    , onSubmit : msg
    }


viewSetDisplayName : DisplayNameFormToMsg msg -> String -> H.Html msg
viewSetDisplayName toMsg displayName =
    H.div
        []
        [ H.div [] [ H.text "What is your name?" ]
        , H.div []
            [ H.input
                [ At.type_ "input"
                , Ev.onInput toMsg.onUpdate
                , At.value displayName
                ]
                []
            ]
        , H.div []
            [ H.button
                [ Ev.onClick toMsg.onSubmit
                ]
                [ H.text "Submit" ]
            ]
        ]
