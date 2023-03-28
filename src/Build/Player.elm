module Build.Player exposing (..)

import App.Player as App exposing (Model, Msg)
import Browser
import Port


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( App.init, Cmd.none )
        , update = App.update Port.send_Player_ToServer identity
        , subscriptions = subscriptions
        , view = App.view
        }


subscriptions model =
    Sub.batch
        [ Port.recv_Player_FromServer App.GotServerMsg
        , Port.socket_onError (\_ -> App.GotSocketMsg App.SocketError)
        , Port.socket_onClose (\_ -> App.GotSocketMsg App.SocketClose)
        ]
