module Build.Host exposing (..)

import App.Host as Host exposing (Flags, Model, Msg)
import Browser
import Port


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = Host.update Port.send_Host_ToServer identity
        , subscriptions = subscriptions
        , view = Host.view
        }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Host.init flags
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Port.recv_Host_FromServer Host.GotServerMsg
