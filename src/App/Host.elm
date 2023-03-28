module App.Host exposing (..)

import Design
import Dict exposing (Dict)
import Game exposing (Game)
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as Events
import Json.Decode
import Process
import QRCode
import Svg.Attributes as SA
import Task


type Msg
    = GotServerMsg FromServer
    | TimeoutJoin String
    | StartGameClicked
    | CreateGameClicked Game
    | TimeoutFrame
    | CanvasClicked
    | TimeoutRound String


type ToServer
    = CreateGame Game
    | StartRound
    | EndRound
    | ShowOptionScreen ShowOptionScreenMsg
    | ClearOptionScreen


type alias ShowOptionScreenMsg =
    { roundId : String
    , optionCount : Int
    }


type FromServer
    = GameCreated String
    | PlayerJoined PlayerJoinedMsg
    | RoundStarted Game.Round
    | RoundEnded RoundResults
    | GameEnded (List PlayerScore)


type alias PlayerJoinedMsg =
    { name : String
    , players : List String
    }


type alias PlayerScore =
    { name : String
    , score : Int
    }


type Model
    = ChooseGame
        { url : String
        , games : List Game
        }
    | WaitingForGame
        { url : String
        }
    | WaitingForPlayers
        { url : String
        , players : List String
        }
    | JustGotPlayer
        { url : String
        , name : String
        , players : List String
        }
    | WaitingForGameStart
    | Countdown Int Game.Round
    | ShowQuestion Game.Round
    | ShowRoundResults Bool RoundResults
    | ShowLeaderboard Bool RoundResults
    | ShowWinner (List PlayerScore)


type alias RoundResults =
    { round : Game.Round
    , roundScores : List PlayerScore
    , totalScores : List PlayerScore
    , answerFreq : List ( Int, Int )
    }


type alias Flags =
    { url : String
    }


init : Flags -> Model
init flags =
    ChooseGame
        { url = flags.url
        , games =
            [ Game.test
            ]
        }


update : (ToServer -> Cmd msg) -> (Msg -> msg) -> Msg -> Model -> ( Model, Cmd msg )
update sendEvent toSelf msg model =
    case ( msg, model ) of
        ( CreateGameClicked game, ChooseGame { url } ) ->
            ( WaitingForGame
                { url = url
                }
            , sendEvent (CreateGame game)
            )

        ( GotServerMsg (GameCreated id), WaitingForGame { url } ) ->
            ( WaitingForPlayers
                { url = url ++ "/join/" ++ id
                , players = []
                }
            , Cmd.none
            )

        ( GotServerMsg (PlayerJoined fromServer), WaitingForPlayers { url } ) ->
            ( JustGotPlayer
                { url = url
                , name = fromServer.name
                , players = fromServer.players
                }
            , TimeoutJoin fromServer.name
                |> toSelf
                |> toCmdWithDelay 3000
            )

        ( GotServerMsg (PlayerJoined fromServer), JustGotPlayer { url } ) ->
            ( JustGotPlayer
                { url = url
                , name = fromServer.name
                , players = fromServer.players
                }
            , TimeoutJoin fromServer.name
                |> toSelf
                |> toCmdWithDelay 3000
            )

        ( GotServerMsg (RoundStarted round), WaitingForGameStart ) ->
            ( Countdown 3 round
            , TimeoutFrame
                |> toSelf
                |> toCmdWithDelay 1000
            )

        ( GotServerMsg (RoundEnded data), ShowQuestion _ ) ->
            ( ShowRoundResults False data
            , TimeoutFrame
                |> toSelf
                |> toCmdWithDelay 1000
            )

        ( GotServerMsg (GameEnded data), _ ) ->
            ( ShowWinner data
            , Cmd.none
            )

        ( StartGameClicked, _ ) ->
            ( WaitingForGameStart
            , sendEvent StartRound
            )

        ( TimeoutFrame, Countdown n round ) ->
            if n <= 1 then
                ( ShowQuestion round
                , ShowOptionScreen
                    { roundId = round.id
                    , optionCount = List.length round.options
                    }
                    |> sendEvent
                )

            else
                ( Countdown (n - 1) round
                , TimeoutFrame
                    |> toSelf
                    |> toCmdWithDelay 1000
                )

        ( TimeoutFrame, ShowQuestion round ) ->
            ( ShowQuestion round
            , Cmd.none
            )

        ( TimeoutJoin n, JustGotPlayer { url, name, players } ) ->
            if n == name then
                ( WaitingForPlayers
                    { url = url
                    , players = name :: players
                    }
                , Cmd.none
                )

            else
                ( model
                , Cmd.none
                )

        ( TimeoutRound id, ShowQuestion round ) ->
            if round.id == id then
                ( model
                , sendEvent EndRound
                )

            else
                ( model
                , Cmd.none
                )

        ( TimeoutFrame, ShowRoundResults False round ) ->
            ( ShowRoundResults True round
            , Cmd.none
            )


        ( CanvasClicked, ShowRoundResults True data ) ->
            ( ShowLeaderboard False data
            , Cmd.batch
                [ sendEvent ClearOptionScreen
                , TimeoutFrame
                    |> toSelf
                    |> toCmdWithDelay 3000
                ]
            )

        ( TimeoutFrame, ShowLeaderboard _ data ) ->
            ( ShowLeaderboard True data
            , CanvasClicked
                |> toSelf
                |> toCmdWithDelay 4000
            )

        ( CanvasClicked, ShowLeaderboard True data ) ->
            ( WaitingForGameStart
            , sendEvent StartRound
            )

        _ ->
            ( model, Cmd.none )


toCmdWithDelay : Float -> msg -> Cmd msg
toCmdWithDelay t msg =
    Process.sleep t
        |> Task.map (\_ -> msg)
        |> Task.perform identity


roundTimeout : Float
roundTimeout =
    10000


view : Model -> Html Msg
view model =
    case model of
        ChooseGame args ->
            view_ChooseGame args.games

        WaitingForGame _ ->
            view_WaitingForGame

        WaitingForPlayers args ->
            view_WaitingForPlayers Nothing args.url args.players

        JustGotPlayer args ->
            view_WaitingForPlayers (Just args.name) args.url args.players

        WaitingForGameStart ->
            view_WaitingForGameStart

        Countdown n _ ->
            view_CountDown n

        ShowQuestion round ->
            view_Question round

        ShowRoundResults tick data ->
            view_RoundResults tick data

        ShowLeaderboard includeRound data ->
            view_Leaderboard includeRound data

        ShowWinner data ->
            view_ShowWinner data


view_ChooseGame : List Game -> Html Msg
view_ChooseGame games =
    Html.div
        [ HA.class "flex-col h-full items-center"
        , HA.style "padding" "2em"
        ]
        [ Html.div
            []
            [ Html.text "Choose game"
            ]
        , Html.div
            [ HA.class "flex-col grow justify-center items-start"
            , HA.style "row-gap" "0.5em"
            ]
            (games
                |> List.map
                    (\game ->
                        Html.div
                            [ HA.class "flex-row items-center"
                            , HA.style "column-gap" "0.75em"
                            ]
                            [ Html.button
                                [ Events.onClick (CreateGameClicked game)
                                ]
                                [ Html.text "Go!"
                                ]
                            , Html.div
                                []
                                [ Html.text game.title
                                ]
                            ]
                    )
            )
        ]


view_WaitingForGame : Html msg
view_WaitingForGame =
    Html.div
        [ HA.class "flex-col justify-center items-center h-full"
        ]
        [ Html.text "Loading..."
        ]


view_WaitingForPlayers : Maybe String -> String -> List String -> Html Msg
view_WaitingForPlayers recentlyJoined url players =
    Html.div
        [ HA.class "grid col-2 text-center h-full"
        , HA.style "row-gap" "2em"
        , HA.style "padding" "2em"
        ]
        [ Html.div
            [ HA.class "flex-col justify-center items-center text-large"
            ]
            [ Html.div
                []
                [ Html.text "Join Game"
                ]
            , QRCode.fromString url
                |> Result.map
                    (QRCode.toSvg
                        [ SA.width "30vw"
                        , SA.height "30vw"
                        ]
                    )
                |> Result.withDefault (Html.text "")
            , Html.div
                [ HA.class "monospace"
                ]
                [ Html.text url
                ]
            ]
        , Html.div
            [ HA.class "flex-col justify-center items-center text-center"
            , HA.style "row-gap" "2em"
            ]
            [ Html.div
                [ HA.class "text-large"
                ]
                (case recentlyJoined of
                    Just name ->
                        [ Html.strong [] [ Html.text name ]
                        , Html.text " just joined the game!!"
                        ]

                    Nothing ->
                        [ Html.text "Players"
                        ]
                )
            , players
                |> List.map
                    (\player ->
                        Html.div
                            []
                            [ Html.text player
                            ]
                    )
                |> Html.div
                    [ HA.class "grid col-2"
                    , HA.style "row-gap" "1em"
                    , HA.style "column-gap" "4em"
                    ]
            , Html.button
                [ Events.onClick StartGameClicked
                ]
                [ Html.text "Start game"
                ]
            ]
        ]


view_WaitingForGameStart : Html Msg
view_WaitingForGameStart =
    Html.div
        [ HA.class "flex-col justify-center items-center text-center h-full text-large"
        ]
        [ Html.text "Waiting for next round to start"
        ]


view_CountDown : Int -> Html Msg
view_CountDown n =
    Html.div
        [ HA.class "flex-col justify-center items-center text-center h-full text-large"
        ]
        [ Html.text "Next question in "
        , Html.text (String.fromInt n)
        ]


view_Question : Game.Round -> Html Msg
view_Question round =
    Html.div
        [ HA.class "flex-col justify-center items-center text-center h-full"
        , HA.style "gap" "1em"
        , HA.style "padding" "1em"
        ]
        [ Html.div
            [ HA.class "flex-col grow justify-center text-large"
            ]
            [ Html.text round.question
            ]
        , Html.div
            [ HA.class "w-full"
            , HA.style "height" "4px"
            , HA.style "background" "#EEE"
            ]
            [ Html.div
                [ HA.class "h-full"
                , HA.style "animation-duration" (String.fromFloat roundTimeout ++ "ms")
                , HA.style "animation-name" "progressbar"
                , HA.style "animation-timing-function" "linear"
                , HA.style "background" "blue"
                , Events.on "animationend" (Json.Decode.succeed (TimeoutRound round.id))
                ]
                []
            ]
        , Html.div
            [ HA.class "grid col-2 w-full"
            , HA.style "gap" "1em"
            ]
            (round.options
                |> List.indexedMap
                    (\idx option ->
                        Html.div
                            [ Design.colorClass idx
                            , HA.class "flex-row answer-row"
                            ]
                            [ Design.answerBlock
                                [ HA.style "width" "2em"
                                ]
                                idx
                            , Html.div
                                [ HA.class "question-text"
                                ]
                                [ Html.text option.answer
                                ]
                            ]
                    )
            )
        ]


view_RoundResults : Bool -> RoundResults -> Html Msg
view_RoundResults tick data =
    let
        total =
            data.answerFreq
                |> List.map Tuple.second
                |> List.sum
                |> toFloat
    in
    Html.div
        [ HA.class "flex-col text-center h-full"
        , Events.onClick CanvasClicked
        , HA.style "gap" "1em"
        , HA.style "padding" "1em"
        ]
        [ Html.div
            [ HA.class "text-large"
            ]
            [ Html.text data.round.question
            ]
        , data.answerFreq
            |> List.map
                (\( answer, freq ) -> Design.bar tick total answer freq)
            |> Html.div
                [ HA.class "flex-row justify-center items-end grow"
                , HA.style "padding" "1em"
                , HA.style "column-gap" "1em"
                , HA.style "margin-top" "2em"
                ]
        , Html.div
            [ HA.class "grid col-2 w-full"
            , HA.style "gap" "1em"
            ]
            (data.round.options
                |> List.indexedMap
                    (\idx option ->
                        Html.div
                            [ Design.colorClass idx
                            , HA.class "flex-row answer-row"
                            , HA.style "opacity"
                                (if option.isCorrect then
                                    "1"

                                 else
                                    "0.2"
                                )
                            , HA.style "outline-style"
                                (if option.isCorrect then
                                    "solid"

                                 else
                                    "none"
                                )
                            ]
                            [ Design.answerBlock
                                [ HA.style "width" "2em"
                                ]
                                idx
                            , Html.div
                                [ HA.class "question-text"
                                ]
                                [ Html.text option.answer
                                ]
                            ]
                    )
            )
        ]


view_Leaderboard : Bool -> RoundResults -> Html Msg
view_Leaderboard tick data =
    let
        roundScores =
            data.roundScores
                |> List.map (\p -> ( p.name, p.score ))
                |> Dict.fromList

        rowHeight =
            1.5

        sortWithScore list =
            if tick then
                list

            else
                list
                    |> List.sortBy .score
                    |> List.reverse

        sorted =
            data.totalScores
                |> List.map
                    (\player ->
                        { name = player.name
                        , score = player.score
                        , round =
                            Dict.get player.name roundScores
                                |> Maybe.withDefault 0
                        }
                    )
                |> List.sortBy (\p -> p.score + p.round)
                |> List.reverse
                |> List.take 15
                |> sortWithScore
                |> List.indexedMap
                    (\idx player ->
                        ( rowHeight * toFloat idx, player )
                    )
                |> List.sortBy (Tuple.second >> .name)

        totalHeight =
            List.length sorted
                |> toFloat
                |> (*) rowHeight
    in
    Html.div
        [ HA.class "flex-col justify-center text-center h-full"
        , HA.style "row-gap" "1em"
        , HA.style "font-size" "1.2em"
        , Events.onClick CanvasClicked
        ]
        [ Html.div
            [ HA.class "text-large"
            ]
            [ Html.text "Leaderboard"
            ]
        , sorted
            |> List.map
                (\( top, player ) ->
                    Html.div
                        [ HA.class "grid col-2 w-full absolute"
                        , HA.style "top" (String.fromFloat top ++ "em")
                        , HA.style "transition" "top 1s"
                        , HA.style "column-gap" "0.6em"
                        ]
                        [ Html.div
                            [ HA.class "text-right"
                            ]
                            [ Html.strong [] [ Html.text player.name ]
                            ]
                        , Html.div
                            [ HA.class "text-left"
                            ]
                            [ if tick then
                                Html.text (String.fromInt (player.score + player.round))

                              else
                                Html.text (String.fromInt player.score)
                            , if player.round > 0 then
                                Html.text (" (+" ++ String.fromInt player.round ++ ")")

                              else
                                Html.text ""
                            ]
                        ]
                )
            |> Html.div
                [ HA.class "relative"
                , HA.style "height" (String.fromFloat totalHeight ++ "em")
                , HA.style "max-height" "100%"
                ]
        ]


view_ShowWinner : List PlayerScore -> Html Msg
view_ShowWinner scores =
    Html.div
        [ HA.class "flex-col justify-center text-center h-full"
        , HA.style "row-gap" "1em"
        , HA.style "font-size" "1.2em"
        , HA.style "line-height" "1.5"
        ]
        [ Html.div
            [ HA.class "text-large"
            ]
            [ Html.text "Winner"
            ]
        , scores
            |> List.sortBy .score
            |> List.reverse
            |> List.take 15
            |> List.map
                (\player ->
                    Html.div
                        [ HA.class "grid col-2"
                        , HA.style "column-gap" "0.5em"
                        ]
                        [ Html.strong
                            [ HA.class "text-right"
                            ]
                            [ Html.text player.name
                            ]
                        , Html.div
                            [ HA.class "text-left"
                            ]
                            [ Html.text (String.fromInt player.score) ]
                        ]
                )
            |> Html.div
                []
        ]
