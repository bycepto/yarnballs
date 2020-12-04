port module App.WebSocket exposing
    ( Message
    , Msg
    , Topic
    , WebSocket
    , connect
    , decodeMessage
    , disconnect
    , fromEvent
    , init
    , isConnected
    , join
    , joinUntilSuccess
    , joined
    , leave
    , matchesRoomId
    , messageReceiver
    , send
    , subscriptions
    , toTopic
    , update
    )

import App.User exposing (User)
import Json.Decode as D
import Json.Encode as E
import Parser as P exposing ((|.), (|=))
import Set exposing (Set)
import Time



-- PORTS


{-| Connect to a websocket
-}
port connectToSocket : E.Value -> Cmd msg


{-| Disconnect from a socket and clear all active channels
-}
port disconnectFromSocket : () -> Cmd msg


{-| Send a message over a websocket
-}
port sendMessage : E.Value -> Cmd msg


{-| Join a topic
-}
port joinTopic : String -> Cmd msg


{-| Leave a topic
-}
port leaveTopic : String -> Cmd msg


{-| Listen for channel join confirmation
-}
port confirmJoinedTopic : (D.Value -> msg) -> Sub msg


{-| Listen for channel leaving confirmation
-}
port confirmLeftTopic : (D.Value -> msg) -> Sub msg


{-| Listen for messages received from a websocket
-}
port messageReceiver : (E.Value -> msg) -> Sub msg


{-| Listen for whether a websocket opened successfully
-}
port confirmSocketOpen : (Bool -> msg) -> Sub msg


{-| Listen for whether a websocket disconnected successfully
-}
port confirmSocketDisconnected : (Bool -> msg) -> Sub msg



-- MODEL


type WebSocket
    = Disconnected
    | Connected Channels


type Channels
    = Channels (Set String)


type Topic
    = Topic String String


type Event a
    = Event a


type alias Message a =
    { topic : Topic
    , event : Event a
    , payload : E.Value
    }


isConnected : WebSocket -> Bool
isConnected ws =
    case ws of
        Disconnected ->
            False

        Connected _ ->
            True


joined : Topic -> WebSocket -> Bool
joined topic ws =
    case ws of
        Disconnected ->
            False

        Connected (Channels channels) ->
            Set.member (topicToString topic) channels


matchesRoomId : String -> Message a -> Bool
matchesRoomId roomId message =
    roomIdFromMessage message == Just roomId


roomIdFromMessage : Message a -> Maybe String
roomIdFromMessage message =
    Result.toMaybe <|
        P.run roomIdParser (topicToString message.topic)


roomIdParser : P.Parser String
roomIdParser =
    P.oneOf
        [ P.succeed identity
            |. P.oneOf
                [ P.keyword "cazadores"
                , P.keyword "hanabi"
                , P.keyword "durak"
                , P.keyword "yarnballs"
                ]
            |. P.symbol ":"
            |= (P.getChompedString <| P.chompUntilEndOr "\n")
        ]


init : WebSocket
init =
    Disconnected



-- DECODE / ENCODE


decodeMessage : (String -> Maybe a) -> D.Decoder (Message a)
decodeMessage eventStringDecoder =
    D.map3
        Message
        (D.field "topic" decodeTopic)
        (D.field "event" (decodeEvent eventStringDecoder))
        (D.field "payload" D.value)


decodeTopic : D.Decoder Topic
decodeTopic =
    D.andThen
        (\s ->
            case String.split ":" s of
                [ "cazadores", id ] ->
                    D.succeed (Topic "cazadores" id)

                [ "hanabi", id ] ->
                    D.succeed (Topic "hanabi" id)

                [ "durak", id ] ->
                    D.succeed (Topic "durak" id)

                [ "yarnballs", id ] ->
                    D.succeed (Topic "yarnballs" id)

                _ ->
                    D.fail ("unknown topic " ++ s)
        )
        D.string


decodeEvent : (String -> Maybe a) -> D.Decoder (Event a)
decodeEvent eventTypeDecoder =
    D.string
        |> D.andThen
            (\s ->
                case eventTypeDecoder s of
                    Just event ->
                        D.succeed (Event event)

                    Nothing ->
                        D.fail ("cannot decode event: " ++ s)
            )


encodeTopic : Topic -> E.Value
encodeTopic topic =
    E.string (topicToString topic)


topicToString : Topic -> String
topicToString (Topic topic subtopic) =
    topic ++ ":" ++ subtopic


toTopic : String -> String -> Topic
toTopic =
    Topic



-- INTERFACE / UPDATE


type alias ToMsg msg =
    Msg -> msg


type Msg
    = Connect
    | GotConnected Bool
    | GotDisconnected
    | JoinTopic Topic
    | GotJoinedTopic (Result D.Error Topic)
    | GotLeftTopic (Result D.Error Topic)


update : Msg -> User -> WebSocket -> ( WebSocket, Cmd msg )
update msg user ws =
    case msg of
        Connect ->
            ( ws, connect user )

        GotConnected False ->
            -- TODO: boolean is always True based on current logic, should it
            -- event be regarded here?
            ( Disconnected, Cmd.none )

        GotConnected True ->
            -- TODO: boolean is always True based on current logic, should it
            -- event be regarded here?
            ( Connected (Channels Set.empty), Cmd.none )

        GotDisconnected ->
            ( Disconnected, Cmd.none )

        JoinTopic topic ->
            case ws of
                Disconnected ->
                    ( ws, Cmd.none )

                Connected (Channels topics) ->
                    if Set.member (topicToString topic) topics then
                        ( ws, Cmd.none )

                    else
                        ( ws, join topic )

        GotJoinedTopic (Err _) ->
            ( ws, Cmd.none )

        GotJoinedTopic (Ok topic) ->
            case ws of
                Disconnected ->
                    ( ws, Cmd.none )

                Connected (Channels topics) ->
                    ( Connected <| Channels <| Set.insert (topicToString topic) topics
                    , Cmd.none
                    )

        GotLeftTopic (Err _) ->
            ( ws, Cmd.none )

        GotLeftTopic (Ok topic) ->
            case ws of
                Disconnected ->
                    ( ws, Cmd.none )

                Connected (Channels topics) ->
                    ( Connected <| Channels <| Set.remove (topicToString topic) topics
                    , Cmd.none
                    )


connect : User -> Cmd msg
connect user =
    -- TODO: check if already connected?
    connectToSocket <|
        E.object [ ( "token", E.string user.accessToken ) ]


disconnect : Cmd msg
disconnect =
    disconnectFromSocket ()


join : Topic -> Cmd msg
join topic =
    joinTopic (topicToString topic)


leave : Topic -> Cmd msg
leave topic =
    leaveTopic (topicToString topic)


send : (a -> String) -> Topic -> a -> E.Value -> Cmd msg
send eventEncoder topic event payload =
    sendMessage <|
        E.object
            [ ( "topic", encodeTopic topic )
            , ( "event", (E.string << eventEncoder) event )
            , ( "payload", payload )
            ]


fromEvent : Event a -> a
fromEvent (Event type_) =
    type_



-- SUBSCRIPTIONS


subscriptions : ToMsg msg -> WebSocket -> Sub msg
subscriptions toMsg _ =
    Sub.batch
        [ confirmSocketOpen (toMsg << GotConnected)
        , confirmSocketDisconnected (\_ -> toMsg GotDisconnected)
        , confirmJoinedTopic (toMsg << GotJoinedTopic << D.decodeValue decodeTopic)
        , confirmLeftTopic (toMsg << GotLeftTopic << D.decodeValue decodeTopic)
        ]


joinUntilSuccess : ToMsg msg -> Topic -> WebSocket -> Sub msg
joinUntilSuccess toMsg topic ws =
    case ws of
        Disconnected ->
            -- TODO: we already connect on auth, is this fallback logic necessary?
            Time.every 1000 (\_ -> toMsg Connect)

        Connected (Channels topics) ->
            if Set.member (topicToString topic) topics then
                Sub.none

            else
                Time.every 1000 (\_ -> toMsg <| JoinTopic topic)
