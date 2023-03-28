module Build.Server exposing (..)

import App.Server as Server exposing (Model, Msg)
import Port


main : Program () Model Msg
main =
    Platform.worker
        { init = \_ -> ( Server.init, Cmd.none )
        , update = Server.update handleEvent identity
        , subscriptions = subscriptions
        }


handleEvent : Server.ToClient -> Cmd msg
handleEvent toClient =
    case toClient of
        Server.ToPlayer id msg ->
            Port.send_Player_FromServer id msg

        Server.ToHost msg ->
            Port.send_Host_FromServer msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Port.recv_Player_ToServer Server.GotPlayerMsg
        , Port.recv_Host_ToServer Server.GotHostMsg
        , Port.server_PlayerLeft Server.PlayerLeft
        ]
