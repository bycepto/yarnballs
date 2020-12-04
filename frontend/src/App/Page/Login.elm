port module App.Page.Login exposing
    ( Msg
    , Page
    , init
    , subscriptions
    , update
    , view
    )

import App
import App.ApiClient exposing (ApiClient)
import App.AuthStatus exposing (AuthStatus)
import App.RollingDice exposing (RollingDice)
import App.RoutingKey exposing (RoutingKey)
import App.WebSocket exposing (WebSocket)
import Css as C
import Html.Styled as H
import Html.Styled.Attributes as At
import Html.Styled.Events as Ev
import Time
import Url



-- PORTS


{-| Request display name from local storage
-}
port getDisplayName : () -> Cmd msg


{-| Receive display name from local storage
-}
port displayNameReceiver : (Maybe String -> msg) -> Sub msg


{-| Set display name in local storage
-}
port setDisplayName : Maybe String -> Cmd msg



-- MODEL


type alias Page =
    { rollingDice : RollingDice
    , displayName : Maybe String
    , redirect : Maybe Url.Url
    }


type alias Model a =
    { -- Http
      a
        | api : ApiClient
        , auth : AuthStatus
        , ws : WebSocket

        -- Url Navigation
        , key : RoutingKey

        -- Dev mode
        , devMode : Bool
    }


init : Maybe Url.Url -> Page
init redirect =
    { rollingDice = App.RollingDice.initWithDuration 2000
    , displayName = Nothing
    , redirect = redirect
    }



-- UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = GotAuthStatusMsg App.AuthStatus.Msg
    | GotRollingDiceMsg App.RollingDice.Msg
    | FetchDisplayName
    | GotDisplayName (Maybe String)
    | UpdateDisplayName String
    | SubmitDisplayName



-- | Redirect


update : ToMsg msg -> Msg -> Model a -> Page -> ( Page, Cmd msg, Model a )
update toMsg msg model page =
    case msg of
        GotAuthStatusMsg subMsg ->
            handleAuthUpdate toMsg subMsg model page

        GotRollingDiceMsg subMsg ->
            updateRollingDice toMsg subMsg model page

        FetchDisplayName ->
            ( page
            , getDisplayName ()
            , model
            )

        GotDisplayName displayName ->
            ( { page | displayName = Just (Maybe.withDefault "" displayName) }
            , Cmd.none
            , model
            )

        UpdateDisplayName value ->
            ( { page | displayName = Just value }
            , Cmd.none
            , model
            )

        SubmitDisplayName ->
            ( page
            , Cmd.batch
                [ setDisplayName page.displayName
                , App.AuthStatus.httpAnonymousSignIn
                    (toMsg << GotAuthStatusMsg)
                    page.redirect
                    model.api
                    page.displayName
                ]
            , model
            )


handleAuthUpdate : ToMsg msg -> App.AuthStatus.Msg -> Model a -> Page -> ( Page, Cmd msg, Model a )
handleAuthUpdate toMsg msg model page =
    model.auth
        |> App.AuthStatus.update (toMsg << GotAuthStatusMsg) msg model.key model.api
        |> (\( newAuth, cmd ) -> ( page, cmd, { model | auth = newAuth } ))


updateRollingDice : ToMsg msg -> App.RollingDice.Msg -> Model a -> Page -> ( Page, Cmd msg, Model a )
updateRollingDice toMsg msg model page =
    page.rollingDice
        |> App.RollingDice.update (toMsg << GotRollingDiceMsg) msg
        |> Tuple.mapFirst (\rollingDice -> { page | rollingDice = rollingDice })
        |> (\( pg, cmd ) -> ( pg, cmd, model ))



-- SUBSCRIPTIONS


subscriptions : ToMsg msg -> Page -> Sub msg
subscriptions toMsg page =
    Sub.batch
        [ App.RollingDice.rollForDuration (toMsg << GotRollingDiceMsg) page.rollingDice
        , case page.displayName of
            Nothing ->
                Time.every 100 (\_ -> toMsg FetchDisplayName)

            Just _ ->
                Sub.none
        , displayNameReceiver (toMsg << GotDisplayName)
        ]



-- VIEWS


view : ToMsg msg -> Model a -> Page -> { title : String, content : H.Html msg }
view toMsg model page =
    { title = "Login"
    , content = viewBody toMsg model page
    }


viewBody : ToMsg msg -> Model a -> Page -> H.Html msg
viewBody toMsg model page =
    H.div
        [ At.css
            [ C.displayFlex
            , C.flexDirection C.column
            , C.justifyContent C.center
            , C.alignItems C.center
            ]
        , At.css
            [ C.height (C.vh 80) ]
        ]
        [ viewContainer toMsg model page
        ]


viewContainer : ToMsg msg -> Model a -> Page -> H.Html msg
viewContainer toMsg model page =
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
        List.concat
            [ [ H.h1 [] [ H.text "GG YO" ] ]
            , [ viewDice toMsg page ]
            , if model.devMode then
                [ H.h2 [] [ H.text "Sign in" ]
                , viewLogin toMsg model page
                , viewBreak
                ]

              else
                []
            , [ H.h2 [] [ H.text "Play anonymously" ]
              , viewAnonymousLogin toMsg page
              ]
            ]


viewDice : ToMsg msg -> Page -> H.Html msg
viewDice toMsg page =
    App.RollingDice.view (toMsg << GotRollingDiceMsg) page.rollingDice


viewLogin : ToMsg msg -> Model a -> Page -> H.Html msg
viewLogin toMsg model page =
    App.AuthStatus.viewLogin (toMsg << GotAuthStatusMsg) page.redirect model.auth


viewAnonymousLogin : ToMsg msg -> Page -> H.Html msg
viewAnonymousLogin toMsg page =
    viewWhatsYourName toMsg page


viewWhatsYourName : (Msg -> msg) -> Page -> H.Html msg
viewWhatsYourName toMsg page =
    H.div
        []
        [ viewSetDisplayName
            { onUpdate = toMsg << UpdateDisplayName
            , onSubmit = toMsg SubmitDisplayName
            }
            page.displayName
        ]


type alias DisplayNameFormToMsg msg =
    { onUpdate : String -> msg
    , onSubmit : msg
    }


viewSetDisplayName : DisplayNameFormToMsg msg -> Maybe String -> H.Html msg
viewSetDisplayName toMsg maybeDisplayName =
    H.div
        [ App.onEnter toMsg.onSubmit
        ]
        [ H.div [] [ H.text "What is your name?" ]
        , H.div []
            [ H.input
                [ At.type_ "input"
                , Ev.onInput toMsg.onUpdate
                , At.value <|
                    case maybeDisplayName of
                        Nothing ->
                            ""

                        Just displayName ->
                            displayName
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


viewBreak : H.Html msg
viewBreak =
    H.hr
        [ At.css
            [ C.width (C.pct 100)
            , C.property "border" "none"
            , C.borderTop3 (C.px 3) C.solid (C.hex "#333")
            , C.color (C.hex "#333")
            , C.overflow C.visible
            , C.textAlign C.center
            , C.height (C.px 5)
            , C.marginTop (C.px 20)
            ]
        , At.css
            [ C.after
                [ C.backgroundColor (C.hex "#fff")
                , C.property "content" "\"OR\""
                , C.padding2 (C.px 0) (C.px 4)
                , C.position C.relative
                , C.top (C.px -12)
                ]
            ]
        ]
        []
