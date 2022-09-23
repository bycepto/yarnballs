module Main exposing (main)

import App.ApiClient exposing (ApiClient)
import App.AuthStatus exposing (AuthStatus)
import App.Navbar exposing (Navbar)
import App.Page.Home
import App.Page.Login
import App.Presence exposing (Presence)
import App.RoutingKey exposing (RoutingKey)
import App.WebSocket exposing (WebSocket)
import Browser exposing (Document)
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav
import Cazadores.Page.Lobby
import Cazadores.Page.Room
import Css as C
import Durak.Page.Lobby
import Durak.Page.Room
import Hanabi.Page.Lobby
import Hanabi.Page.Room
import Html.Styled as H
import Html.Styled.Attributes as At
import Task
import Url
import Url.Parser as P exposing ((</>))
import Yarnballs.Page.Room



-- PROGRAM


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { -- Http
      api : ApiClient
    , auth : AuthStatus

    -- dev
    , devMode : Bool

    -- Display
    , width : Float

    -- WebSocket
    , ws : WebSocket

    -- Presences (TODO: move to game where necessary)
    , presence : Presence

    -- Navbar
    , navbar : Navbar

    -- Url Navigation
    , key : RoutingKey
    , route : Maybe Route
    }


type Route
    = Home
    | Login App.Page.Login.Page
    | CazadoresLobby Cazadores.Page.Lobby.Page
    | CazadoresRoom Cazadores.Page.Room.Page String
    | HanabiLobby Hanabi.Page.Lobby.Page
    | HanabiRoom Hanabi.Page.Room.Page String
    | DurakLobby Durak.Page.Lobby.Page
    | DurakRoom Durak.Page.Room.Page String
    | YarnballsRoom Yarnballs.Page.Room.Page


router : Bool -> P.Parser (Route -> a) a
router devMode =
    P.oneOf
        [ P.map Home <| P.top
        , P.map (Login (App.Page.Login.init Nothing)) <| P.top </> P.s "login"

        -- Cazadores
        , P.map (CazadoresLobby Cazadores.Page.Lobby.init) <| P.top </> P.s "cazadores"
        , P.map (CazadoresRoom Cazadores.Page.Room.init) <| P.top </> P.s "cazadores" </> P.string

        -- Hanabi
        , P.map (HanabiLobby Hanabi.Page.Lobby.init) <| P.top </> P.s "hanabi"
        , P.map (HanabiRoom Hanabi.Page.Room.init) <| P.top </> P.s "hanabi" </> P.string

        -- Durak
        , P.map (DurakLobby Durak.Page.Lobby.init) <| P.top </> P.s "durak"
        , P.map (DurakRoom Durak.Page.Room.init) <| P.top </> P.s "durak" </> P.string

        -- Yarnballs
        , P.map (YarnballsRoom <| Yarnballs.Page.Room.init devMode) <| P.top </> P.s "yarnballs"
        ]



-- INITIALIZE


type alias Flags =
    { baseUrl : String
    , devMode : Bool
    , refreshToken : Maybe String
    }


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    initAuth flags url
        |> initMainFromAuth flags url key
        |> initRoutes


initAuth : Flags -> Url.Url -> ( AuthStatus, Cmd Msg )
initAuth flags url =
    App.AuthStatus.init GotAuthStatusMsg
        (case P.parse (router flags.devMode) url of
            Just (Login _) ->
                Nothing

            _ ->
                Just url
        )
        flags.baseUrl
        flags.refreshToken


initMainFromAuth : Flags -> Url.Url -> Nav.Key -> ( AuthStatus, Cmd Msg ) -> ( Model, Cmd Msg )
initMainFromAuth flags url key authWithCmd =
    Tuple.mapBoth
        (initModelFromAuth flags url key)
        initCmdFromAuth
        authWithCmd


initModelFromAuth : Flags -> Url.Url -> Nav.Key -> AuthStatus -> Model
initModelFromAuth flags url key auth =
    { api = App.ApiClient.init flags.baseUrl
    , auth = auth
    , devMode = flags.devMode

    -- Will get width of viewport shortly
    , width = 0

    -- Socket
    , ws = App.WebSocket.init
    , presence = App.Presence.empty

    -- Navigation
    , navbar = App.Navbar.init

    -- Url Navigation
    , key = App.RoutingKey.init key
    , route = updateRoute flags.devMode auth url
    }


initCmdFromAuth : Cmd Msg -> Cmd Msg
initCmdFromAuth cmd =
    Cmd.batch [ initViewport, cmd ]


initViewport : Cmd Msg
initViewport =
    Task.perform (\vp -> GotViewportWidth vp.viewport.width) Browser.Dom.getViewport


initRoutes : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
initRoutes ( model, cmd ) =
    model
        |> setupRoute Nothing
        |> Tuple.mapSecond (\routeCmd -> Cmd.batch [ cmd, routeCmd ])



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
      -- Mobile view updates
    | GotViewportWidth Float
      -- WebSocket
    | GotWebSocketMsg App.WebSocket.Msg
    | GotPresenceMsg App.Presence.Msg
      -- AuthStatus
    | GotAuthStatusMsg App.AuthStatus.Msg
      -- Navbar
    | GotNavbarMsg App.Navbar.Msg
      -- Pages
    | GotPageLoginMsg App.Page.Login.Msg
    | GotPageCazadoresLobbyMsg Cazadores.Page.Lobby.Msg
    | GotPageCazadoresRoomMsg String Cazadores.Page.Room.Msg
    | GotHanabiPageLobbyMsg Hanabi.Page.Lobby.Msg
    | GotHanabiPageRoomMsg String Hanabi.Page.Room.Msg
    | GotDurakPageLobbyMsg Durak.Page.Lobby.Msg
    | GotDurakPageRoomMsg String Durak.Page.Room.Msg
    | GotYarnballsPageRoomMsg Yarnballs.Page.Room.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, App.RoutingKey.pushUrl url model.key )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            setupRoute model.route { model | route = updateRoute model.devMode model.auth url }

        GotViewportWidth width ->
            ( { model | width = width }, Cmd.none )

        GotWebSocketMsg subMsg ->
            case App.AuthStatus.toUser model.auth of
                Nothing ->
                    ( model, Cmd.none )

                Just user ->
                    model.ws
                        |> App.WebSocket.update subMsg user
                        |> Tuple.mapFirst (\ws -> { model | ws = ws })

        GotPresenceMsg subMsg ->
            ( { model | presence = App.Presence.update subMsg model.presence }
            , Cmd.none
            )

        GotNavbarMsg subMsg ->
            model.navbar
                |> App.Navbar.update GotNavbarMsg subMsg model
                |> handleNavbarUpdateWithModel

        GotAuthStatusMsg subMsg ->
            model.auth
                |> App.AuthStatus.update GotAuthStatusMsg subMsg model.key model.api
                |> Tuple.mapFirst (\auth -> { model | auth = auth })

        GotPageLoginMsg subMsg ->
            case model.route of
                Just (Login page) ->
                    handlePageUpdateWithModel
                        Login
                        (App.Page.Login.update GotPageLoginMsg subMsg model page)

                _ ->
                    ( model, Cmd.none )

        GotPageCazadoresLobbyMsg subMsg ->
            case model.route of
                Just (CazadoresLobby page) ->
                    handlePageUpdateWithModel
                        CazadoresLobby
                        (Cazadores.Page.Lobby.update subMsg model page)

                _ ->
                    ( model, Cmd.none )

        GotPageCazadoresRoomMsg roomId subMsg ->
            case model.route of
                Just (CazadoresRoom page id) ->
                    -- TODO: make it impossible to have a different string / room page
                    if id == roomId then
                        handlePageUpdateWithModel
                            (\pg -> CazadoresRoom pg roomId)
                            (Cazadores.Page.Room.update (GotPageCazadoresRoomMsg roomId) subMsg roomId model page)

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotHanabiPageLobbyMsg subMsg ->
            case model.route of
                Just (HanabiLobby page) ->
                    handlePageUpdateWithModel
                        HanabiLobby
                        (Hanabi.Page.Lobby.update subMsg model page)

                _ ->
                    ( model, Cmd.none )

        GotHanabiPageRoomMsg roomId subMsg ->
            case model.route of
                Just (HanabiRoom page id) ->
                    -- TODO: make it impossible to have a different string / room page
                    if id == roomId then
                        handlePageUpdateWithModel
                            (\pg -> HanabiRoom pg roomId)
                            (Hanabi.Page.Room.update subMsg roomId model page)

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotDurakPageLobbyMsg subMsg ->
            case model.route of
                Just (DurakLobby page) ->
                    handlePageUpdateWithModel
                        DurakLobby
                        (Durak.Page.Lobby.update subMsg model page)

                _ ->
                    ( model, Cmd.none )

        GotDurakPageRoomMsg roomId subMsg ->
            case model.route of
                Just (DurakRoom page id) ->
                    -- TODO: make it impossible to have a different string / round page
                    if id == roomId then
                        handlePageUpdateWithModel
                            (\pg -> DurakRoom pg roomId)
                            (Durak.Page.Room.update (GotDurakPageRoomMsg roomId) subMsg model page)

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotYarnballsPageRoomMsg subMsg ->
            case model.route of
                Just (YarnballsRoom page) ->
                    handlePageUpdateWithModel YarnballsRoom (Yarnballs.Page.Room.update subMsg model page)

                _ ->
                    ( model, Cmd.none )


handleNavbarUpdateWithModel : ( Navbar, Cmd Msg, Model ) -> ( Model, Cmd Msg )
handleNavbarUpdateWithModel ( navbar, cmd, model ) =
    ( { model | navbar = navbar }, cmd )


handlePageUpdateWithModel : (pg -> Route) -> ( pg, Cmd Msg, Model ) -> ( Model, Cmd Msg )
handlePageUpdateWithModel toRoute ( page, cmd, model ) =
    handlePageUpdate toRoute model ( page, cmd )


handlePageUpdate : (pg -> Route) -> Model -> ( pg, Cmd Msg ) -> ( Model, Cmd Msg )
handlePageUpdate toRoute model ( page, cmd ) =
    ( { model | route = Just (toRoute page) }, cmd )


updateRoute : Bool -> AuthStatus -> Url.Url -> Maybe Route
updateRoute devMode auth url =
    case App.AuthStatus.toUser auth of
        Just _ ->
            P.parse (router devMode) url

        Nothing ->
            (Just << Login << App.Page.Login.init) <|
                case P.parse (router devMode) url of
                    Just (Login _) ->
                        Nothing

                    _ ->
                        Just url


setupRoute : Maybe Route -> Model -> ( Model, Cmd Msg )
setupRoute oldRoute model =
    if model.route == oldRoute then
        ( model, Cmd.none )

    else
        ( model
        , Cmd.batch
            [ unloadRoute model.ws oldRoute
            , loadRoute model.ws model.route
            ]
        )


{-| initialize new routes
-}
loadRoute : WebSocket -> Maybe Route -> Cmd Msg
loadRoute ws route =
    case route of
        Just (Login _) ->
            Cmd.none

        Just Home ->
            Cmd.none

        Just (CazadoresLobby _) ->
            Cazadores.Page.Lobby.load GotPageCazadoresLobbyMsg ws

        Just (CazadoresRoom _ roundId) ->
            Cazadores.Page.Room.load roundId ws

        Just (HanabiLobby _) ->
            Hanabi.Page.Lobby.load ws

        Just (HanabiRoom _ roundId) ->
            Hanabi.Page.Room.load roundId ws

        Just (DurakLobby _) ->
            Durak.Page.Lobby.load GotDurakPageLobbyMsg ws

        Just (DurakRoom _ roundId) ->
            Durak.Page.Room.load roundId ws

        Just (YarnballsRoom _) ->
            Yarnballs.Page.Room.load ws

        Nothing ->
            Cmd.none


{-| terminate old routes
-}
unloadRoute : WebSocket -> Maybe Route -> Cmd Msg
unloadRoute ws route =
    case route of
        Just (Login _) ->
            Cmd.none

        Just Home ->
            Cmd.none

        Just (CazadoresLobby _) ->
            Cazadores.Page.Lobby.unload ws

        Just (CazadoresRoom _ id) ->
            Cazadores.Page.Room.unload id ws

        Just (HanabiLobby _) ->
            Hanabi.Page.Lobby.unload ws

        Just (HanabiRoom _ roundId) ->
            Hanabi.Page.Room.unload roundId ws

        Just (DurakLobby _) ->
            Durak.Page.Lobby.unload ws

        Just (DurakRoom _ roundId) ->
            Durak.Page.Room.unload roundId ws

        Just (YarnballsRoom _) ->
            Yarnballs.Page.Room.unload ws

        Nothing ->
            Cmd.none



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ App.Presence.subscriptions GotPresenceMsg
        , App.WebSocket.subscriptions GotWebSocketMsg model.ws
        , Browser.Events.onResize (\w _ -> GotViewportWidth (toFloat w))
        , routeSubscriptions model
        ]


routeSubscriptions : Model -> Sub Msg
routeSubscriptions model =
    case model.route of
        Nothing ->
            Sub.none

        Just (Login page) ->
            App.Page.Login.subscriptions GotPageLoginMsg page

        Just Home ->
            Sub.none

        Just (CazadoresLobby _) ->
            Cazadores.Page.Lobby.subscriptions GotPageCazadoresLobbyMsg model

        Just (CazadoresRoom page roundId) ->
            Cazadores.Page.Room.subscriptions (GotPageCazadoresRoomMsg roundId) roundId model page

        Just (HanabiLobby _) ->
            Hanabi.Page.Lobby.subscriptions GotHanabiPageLobbyMsg model

        Just (HanabiRoom page roundId) ->
            Hanabi.Page.Room.subscriptions (GotHanabiPageRoomMsg roundId) roundId model page

        Just (DurakLobby _) ->
            Durak.Page.Lobby.subscriptions GotDurakPageLobbyMsg model

        Just (DurakRoom page roundId) ->
            Durak.Page.Room.subscriptions (GotDurakPageRoomMsg roundId) roundId model page

        Just (YarnballsRoom _) ->
            Yarnballs.Page.Room.subscriptions GotYarnballsPageRoomMsg model.ws



-- VIEWS


view : Model -> Document Msg
view model =
    let
        doc =
            viewPage model
    in
    { title = "GG Yo | " ++ doc.title
    , body =
        List.map
            H.toUnstyled
            [ H.div stylePage [ doc.content ] ]
    }


stylePage : List (H.Attribute Msg)
stylePage =
    [ At.css
        [ -- Prevent double-tap zoom
          C.touchAction C.manipulation

        -- Prevent scrollbar from changing width
        , C.width (C.vw 100)

        -- fill viewport
        , C.height (C.vh 100)
        ]
    ]


viewPage : Model -> { title : String, content : H.Html Msg }
viewPage model =
    case ( App.AuthStatus.toUser model.auth, model.route ) of
        ( _, Just (Login page) ) ->
            App.Page.Login.view GotPageLoginMsg model page

        ( _, Just Home ) ->
            viewWithNavbar [] model <|
                App.Page.Home.view model.devMode

        ( _, Just (CazadoresLobby page) ) ->
            viewWithNavbar
                [ ( "Cazadores", "cazadores" ) ]
                model
            <|
                Cazadores.Page.Lobby.view GotPageCazadoresLobbyMsg model page

        ( _, Just (CazadoresRoom page roomId) ) ->
            viewWithNavbar
                [ ( "Cazadores", "cazadores" )
                , ( shortRoundId roomId, roomId )
                ]
                model
            <|
                Cazadores.Page.Room.view (GotPageCazadoresRoomMsg roomId) roomId model page

        ( _, Just (HanabiLobby page) ) ->
            viewWithNavbar
                [ ( "Hanabi", "hanabi" ) ]
                model
            <|
                Hanabi.Page.Lobby.view GotHanabiPageLobbyMsg model page

        ( Nothing, Just (HanabiRoom _ _) ) ->
            -- TODO: redirect to login?
            { title = "", content = H.div [] [] }

        ( Just user, Just (HanabiRoom page roomId) ) ->
            viewWithNavbar
                [ ( "Hanabi", "hanabi" )
                , ( shortRoundId roomId, roomId )
                ]
                model
            <|
                Hanabi.Page.Room.view (GotHanabiPageRoomMsg roomId) model user roomId page

        ( _, Just (DurakLobby page) ) ->
            viewWithNavbar
                [ ( "Durak", "durak" ) ]
                model
            <|
                Durak.Page.Lobby.view GotDurakPageLobbyMsg model page

        ( Nothing, Just (DurakRoom _ _) ) ->
            -- TODO: redirect to login?
            { title = "", content = H.div [] [] }

        ( Just _, Just (DurakRoom page roomId) ) ->
            viewWithNavbar
                [ ( "Durak", "durak" )
                , ( shortRoundId roomId, roomId )
                ]
                model
            <|
                Durak.Page.Room.view (GotDurakPageRoomMsg roomId) model roomId page

        ( _, Just (YarnballsRoom page) ) ->
            let
                doc =
                    Yarnballs.Page.Room.view GotYarnballsPageRoomMsg model page
            in
            viewWithNavbar
                [ ( "Yarnballs", "yarnballs" ) ]
                model
            <|
                { title = doc.title
                , content = H.fromUnstyled doc.content
                }

        ( _, Nothing ) ->
            -- TODO: define 404 page
            { title = "Not Found"
            , content = H.div [] [ H.text "Not Found" ]
            }


viewWithNavbar : List ( String, String ) -> Model -> { title : String, content : H.Html Msg } -> { title : String, content : H.Html Msg }
viewWithNavbar namedPathSegments model doc =
    { title = doc.title
    , content =
        H.div
            [ At.css
                [ C.displayFlex
                , C.flexDirection C.column
                , C.height (C.pct 100)
                ]
            ]
            [ App.Navbar.view GotNavbarMsg namedPathSegments model model.navbar
            , H.div
                [ At.css
                    [ C.flexGrow (C.int 1) ]
                ]
                [ doc.content ]
            ]
    }


shortRoundId : String -> String
shortRoundId roundId =
    case List.head (String.split "-" <| roundId) of
        Just slug ->
            String.toUpper slug

        Nothing ->
            "???"
