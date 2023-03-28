port module Port exposing (..)

import App.Host
import App.Player
import Game exposing (Game, Round)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)


type alias WithId a =
    { id : String
    , msg : a
    }


withId : (a -> b) -> WithId a -> WithId b
withId fn arg =
    { id = arg.id
    , msg = fn arg.msg
    }


port socket_onError : (String -> msg) -> Sub msg


port socket_onClose : (String -> msg) -> Sub msg


port server_PlayerLeft : (String -> msg) -> Sub msg



-- PLAYER <-> SERVER PORTS


send_Player_ToServer : App.Player.ToServer -> Cmd msg
send_Player_ToServer msg =
    case msg of
        App.Player.JoinGame name ->
            send_Player_ToServer_JoinGame name

        App.Player.SelectAnswer args ->
            send_Player_ToServer_SelectAnswer args


recv_Player_ToServer : (WithId App.Player.ToServer -> msg) -> Sub msg
recv_Player_ToServer toMsg =
    Sub.batch
        [ recv_Player_ToServer_JoinGame (withId App.Player.JoinGame)
        , recv_Player_ToServer_SelectAnswer (withId App.Player.SelectAnswer)
        ]
        |> Sub.map toMsg


send_Player_FromServer : String -> App.Player.FromServer -> Cmd msg
send_Player_FromServer id msg =
    case msg of
        App.Player.JoinSuccess ->
            send_Player_FromServer_JoinSuccess
                { id = id
                , msg = {}
                }

        App.Player.JoinFail args ->
            send_Player_FromServer_JoinFail
                { id = id
                , msg = args
                }

        App.Player.RoundStarted args ->
            send_Player_FromServer_GameStarted
                { id = id
                , msg = args
                }

        App.Player.AnswerWasTooLate ->
            send_Player_FromServer_AnswerTooLate
                { id = id
                , msg = {}
                }

        App.Player.ClearOptionScreen ->
            send_Player_FromServer_ClearOptionScreen
                { id = id
                , msg = {}
                }

        App.Player.GameEnded pos ->
            send_Player_FromServer_GameEnded
                { id = id
                , msg = pos
                }

        App.Player.GameNotFound ->
            send_Player_FromServer_GameNotFound
                { id = id
                , msg = {}
                }


recv_Player_FromServer : (App.Player.FromServer -> msg) -> Sub msg
recv_Player_FromServer toMsg =
    Sub.batch
        [ recv_Player_FromServer_JoinSuccess (\_ -> App.Player.JoinSuccess)
        , recv_Player_FromServer_JoinFail App.Player.JoinFail
        , recv_Player_FromServer_GameStarted App.Player.RoundStarted
        , recv_Player_FromServer_AnswerTooLate (\_ -> App.Player.AnswerWasTooLate)
        , recv_Player_FromServer_ClearOptionScreen (\_ -> App.Player.ClearOptionScreen)
        , recv_Player_FromServer_GameEnded App.Player.GameEnded
        , recv_Player_FromServer_GameNotFound (\_ -> App.Player.GameNotFound)
        ]
        |> Sub.map toMsg



-- Player ToServer


port send_Player_ToServer_JoinGame : String -> Cmd msg


port recv_Player_ToServer_JoinGame : (WithId String -> msg) -> Sub msg


port send_Player_ToServer_SelectAnswer : App.Player.SelectAnswerMsg -> Cmd msg


port recv_Player_ToServer_SelectAnswer : (WithId App.Player.SelectAnswerMsg -> msg) -> Sub msg



-- Player FromServer


port send_Player_FromServer_JoinSuccess : WithId {} -> Cmd msg


port recv_Player_FromServer_JoinSuccess : ({} -> msg) -> Sub msg


port send_Player_FromServer_JoinFail : WithId App.Player.JoinFailMsg -> Cmd msg


port recv_Player_FromServer_JoinFail : (App.Player.JoinFailMsg -> msg) -> Sub msg


port send_Player_FromServer_GameStarted : WithId App.Player.RoundStartedMsg -> Cmd msg


port recv_Player_FromServer_GameStarted : (App.Player.RoundStartedMsg -> msg) -> Sub msg


port send_Player_FromServer_AnswerTooLate : WithId {} -> Cmd msg


port recv_Player_FromServer_AnswerTooLate : ({} -> msg) -> Sub msg


port send_Player_FromServer_ClearOptionScreen : WithId {} -> Cmd msg


port recv_Player_FromServer_ClearOptionScreen : ({} -> msg) -> Sub msg


port send_Player_FromServer_GameEnded : WithId Int -> Cmd msg


port recv_Player_FromServer_GameEnded : (Int -> msg) -> Sub msg


port send_Player_FromServer_GameNotFound : WithId {} -> Cmd msg


port recv_Player_FromServer_GameNotFound : ({} -> msg) -> Sub msg



-- GAME <-> SERVER PORTS


send_Host_ToServer : App.Host.ToServer -> Cmd msg
send_Host_ToServer msg =
    case msg of
        App.Host.CreateGame game ->
            send_Host_ToServer_CreateGame game

        App.Host.StartRound ->
            send_Host_ToServer_StartRound {}

        App.Host.EndRound ->
            send_Host_ToServer_EndRound {}

        App.Host.ShowOptionScreen args ->
            send_Host_ToServer_ShowOptionScreen args

        App.Host.ClearOptionScreen ->
            send_Host_ToServer_ClearOptionScreen {}


recv_Host_ToServer : (App.Host.ToServer -> msg) -> Sub msg
recv_Host_ToServer toMsg =
    Sub.batch
        [ recv_Host_ToServer_CreateGame App.Host.CreateGame
        , recv_Host_ToServer_StartRound (\_ -> App.Host.StartRound)
        , recv_Host_ToServer_EndRound (\_ -> App.Host.EndRound)
        , recv_Host_ToServer_ShowOptionScreen App.Host.ShowOptionScreen
        , recv_Host_ToServer_ClearOptionScreen (\_ -> App.Host.ClearOptionScreen)
        ]
        |> Sub.map toMsg


port send_Host_ToServer_CreateGame : Game -> Cmd msg


port recv_Host_ToServer_CreateGame : (Game -> msg) -> Sub msg


port send_Host_ToServer_StartRound : {} -> Cmd msg


port recv_Host_ToServer_StartRound : ({} -> msg) -> Sub msg


port send_Host_ToServer_EndRound : {} -> Cmd msg


port recv_Host_ToServer_EndRound : ({} -> msg) -> Sub msg


port send_Host_ToServer_ShowOptionScreen : App.Host.ShowOptionScreenMsg -> Cmd msg


port recv_Host_ToServer_ShowOptionScreen : (App.Host.ShowOptionScreenMsg -> msg) -> Sub msg


port send_Host_ToServer_ClearOptionScreen : {} -> Cmd msg


port recv_Host_ToServer_ClearOptionScreen : ({} -> msg) -> Sub msg


send_Host_FromServer : App.Host.FromServer -> Cmd msg
send_Host_FromServer msg =
    case msg of
        App.Host.GameCreated args ->
            send_Host_FromServer_GameCreated args

        App.Host.PlayerJoined args ->
            send_Host_FromServer_PlayerJoined args

        App.Host.RoundStarted round ->
            send_Host_FromServer_RoundStarted round

        App.Host.RoundEnded results ->
            send_Host_FromServer_RoundEnded results

        App.Host.GameEnded scores ->
            send_Host_FromServer_GameEnded scores


recv_Host_FromServer : (App.Host.FromServer -> msg) -> Sub msg
recv_Host_FromServer toMsg =
    Sub.batch
        [ recv_Host_FromServer_GameCreated App.Host.GameCreated
        , recv_Host_FromServer_PlayerJoined App.Host.PlayerJoined
        , recv_Host_FromServer_RoundStarted App.Host.RoundStarted
        , recv_Host_FromServer_RoundEnded App.Host.RoundEnded
        , recv_Host_FromServer_GameEnded App.Host.GameEnded
        ]
        |> Sub.map toMsg


port send_Host_FromServer_GameCreated : String -> Cmd msg


port recv_Host_FromServer_GameCreated : (String -> msg) -> Sub msg


port send_Host_FromServer_PlayerJoined : App.Host.PlayerJoinedMsg -> Cmd msg


port recv_Host_FromServer_PlayerJoined : (App.Host.PlayerJoinedMsg -> msg) -> Sub msg


port send_Host_FromServer_RoundStarted : Round -> Cmd msg


port recv_Host_FromServer_RoundStarted : (Round -> msg) -> Sub msg


port send_Host_FromServer_RoundEnded : App.Host.RoundResults -> Cmd msg


port recv_Host_FromServer_RoundEnded : (App.Host.RoundResults -> msg) -> Sub msg


port send_Host_FromServer_GameEnded : List App.Host.PlayerScore -> Cmd msg


port recv_Host_FromServer_GameEnded : (List App.Host.PlayerScore -> msg) -> Sub msg
