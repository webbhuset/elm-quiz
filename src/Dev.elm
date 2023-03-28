module Dev exposing (..)

import App.Host
import App.Player
import App.Server
import Browser
import Design
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as Events
import Process
import Task


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type Msg
    = HostMsg App.Host.Msg
    | PlayerMsg String App.Player.Msg
    | ServerMsg App.Server.Msg
    | AddPlayerClicked


type alias Model =
    { player : Dict String App.Player.Model
    , server : App.Server.Model
    , host : App.Host.Model
    , lastId : Int
    }


type alias Flags =
    ()


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        server =
            App.Server.init

        host =
            App.Host.init { url = "http://example.com" }

        player =
            App.Player.init
    in
    ( { player = Dict.singleton "0" player
      , server = server
      , host = host
      , lastId = 1
      }
    , Cmd.none
    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        HostMsg gameMsg ->
            let
                ( new, cmd ) =
                    App.Host.update
                        handleGameEvent
                        HostMsg
                        gameMsg
                        model.host
            in
            ( { model | host = new }
            , cmd
            )

        PlayerMsg id playerMsg ->
            case Dict.get id model.player of
                Just playerModel ->
                    let
                        ( new, cmd ) =
                            App.Player.update
                                (handlePlayerEvent id)
                                (PlayerMsg id)
                                playerMsg
                                playerModel
                    in
                    ( { model | player = Dict.insert id new model.player }
                    , cmd
                    )

                Nothing ->
                    ( model, Cmd.none )

        ServerMsg serverMsg ->
            let
                ( new, cmd ) =
                    App.Server.update
                        handleServerEvent
                        ServerMsg
                        serverMsg
                        model.server
            in
            ( { model | server = new }
            , cmd
            )

        AddPlayerClicked ->
            let
                id =
                    String.fromInt model.lastId

                player =
                    App.Player.init
            in
            ( { model
                | player = Dict.insert id player model.player
                , lastId = model.lastId + 1
              }
            , Cmd.none
            )


handlePlayerEvent : String -> App.Player.ToServer -> Cmd Msg
handlePlayerEvent id out =
    App.Server.GotPlayerMsg { id = id, msg = out }
        |> ServerMsg
        |> send


handleServerEvent : App.Server.ToClient -> Cmd Msg
handleServerEvent out =
    case out of
        App.Server.ToPlayer id msg ->
            App.Player.GotServerMsg msg
                |> PlayerMsg id
                |> send

        App.Server.ToHost msg ->
            App.Host.GotServerMsg msg
                |> HostMsg
                |> send


handleGameEvent : App.Host.ToServer -> Cmd Msg
handleGameEvent out =
    App.Server.GotHostMsg out
        |> ServerMsg
        |> send


send msg =
    Process.sleep 200
        |> Task.map (\_ -> msg)
        |> Task.perform identity


view : Model -> Html Msg
view model =
    Html.div
        [ HA.class "flex-col"
        , HA.style "padding" "1em"
        , HA.style "row-gap" "1em"
        ]
        [ Design.stylesheet "/src/Build/common.css"
        , Design.stylesheet "/src/Build/host.css"
        , Design.stylesheet "/src/Build/player.css"
        , Design.stylesheet "/src/Build/dev.css"
        , Html.div
            []
            [ Html.button
                [ Events.onClick AddPlayerClicked
                ]
                [ Html.text "+ Add Player"
                ]
            ]
        , Html.div
            [ HA.class "grid dev-player-grid"
            ]
            (model.player
                |> Dict.map
                    (\id player ->
                        App.Player.view player
                            |> Html.map (PlayerMsg id)
                    )
                |> Dict.values
            )
        , Html.div
            [ HA.class "dev-game"
            ]
            [ App.Host.view model.host
                |> Html.map HostMsg
            ]
        ]
