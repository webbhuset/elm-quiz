module App.Server exposing (..)

import App.Host
import App.Player
import Dict exposing (Dict)
import Dict.Extra
import Game exposing (Game)
import Set exposing (Set)


type Msg
    = GotPlayerMsg
        { id : String
        , msg : App.Player.ToServer
        }
    | GotHostMsg App.Host.ToServer
    | PlayerLeft String


type ToClient
    = ToPlayer String App.Player.FromServer
    | ToHost App.Host.FromServer


type Model
    = WaitingForGame
    | Playing Game State


type State
    = WaitingForPlayers
        { occupiedNames : Set String
        , players : Dict String Player
        , game : Game
        }
    | WaitingForAnswers
        { round : Game.Round
        , answers : List PlayerAnswer
        , upcomming : List Game.Round
        , completed : List Completed
        , players : Dict String Player
        }
    | DisplayingRoundResults
        { round : Game.Round
        , upcomming : List Game.Round
        , scores : List ( String, Int )
        , completed : List Completed
        , players : Dict String Player
        }


type alias Completed =
    { round : Game.Round
    , scores : List ( String, Int )
    }


type alias PlayerAnswer =
    { playerId : String
    , answer : Int
    }


type alias Player =
    { name : String
    , isConnected : Bool
    }


init : Model
init =
    WaitingForGame


update : (ToClient -> Cmd msg) -> (Msg -> msg) -> Msg -> Model -> ( Model, Cmd msg )
update sendEvent toSelf msg model =
    case (msg, model)  of
        ( GotPlayerMsg args, Playing game state ) ->
            handlePlayerEvent sendEvent toSelf args.id args.msg state
                |> Tuple.mapFirst (Playing game)

        ( GotPlayerMsg args, WaitingForGame ) ->
            ( model
            , App.Player.GameNotFound
                |> ToPlayer args.id
                |> sendEvent
            )

        ( GotHostMsg hostMsg, _ ) ->
            handleHostEvent sendEvent toSelf hostMsg model

        ( PlayerLeft id, Playing game state  ) ->
            ( case state of
                WaitingForPlayers data ->
                    handlePlayerDisconnect id data
                        |> WaitingForPlayers
                        |> Playing game

                WaitingForAnswers data ->
                    handlePlayerDisconnect id data
                        |> WaitingForAnswers
                        |> Playing game

                DisplayingRoundResults data ->
                    handlePlayerDisconnect id data
                        |> DisplayingRoundResults
                        |> Playing game
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )



handlePlayerDisconnect :
    String
    -> { a | players : Dict String Player }
    -> { a | players : Dict String Player }
handlePlayerDisconnect id data =
    { data
        | players =
            Dict.update
                id
                (Maybe.map
                    (\p -> { p | isConnected = False })
                )
                data.players
    }


handlePlayerEvent :
    (ToClient -> Cmd msg)
    -> (Msg -> msg)
    -> String
    -> App.Player.ToServer
    -> State
    -> ( State, Cmd msg )
handlePlayerEvent sendEvent toSelf id msg state =
    case ( msg, state ) of
        ( App.Player.JoinGame requestedName, WaitingForPlayers data ) ->
            handlePlayerJoin sendEvent id requestedName data

        ( App.Player.JoinGame requestedName, _ ) ->
            ( state
            , App.Player.JoinFail
                { reason = "Game already started"
                , name = requestedName
                }
                |> ToPlayer id
                |> sendEvent
            )

        ( App.Player.SelectAnswer fromPlayer, WaitingForAnswers data ) ->
            handlePlayerAnswer sendEvent toSelf id fromPlayer data

        ( App.Player.SelectAnswer _, _ ) ->
            ( state
            , App.Player.AnswerWasTooLate
                |> ToPlayer id
                |> sendEvent
            )


handlePlayerJoin sendEvent id requestedName data =
    let
        name =
            String.toUpper requestedName

        error =
            if String.isEmpty name then
                Just "Name can't be empty"

            else if Set.member name data.occupiedNames then
                Just "Name already taken"

            else
                Nothing
    in
    case error of
        Just reason ->
            ( WaitingForPlayers data
            , App.Player.JoinFail
                { reason = reason
                , name = name
                }
                |> ToPlayer id
                |> sendEvent
            )

        Nothing ->
            ( WaitingForPlayers
                { data
                    | players =
                        Dict.insert
                            id
                            { name = name, isConnected = True }
                            data.players
                    , occupiedNames = Set.insert name data.occupiedNames
                }
            , Cmd.batch
                [ ToPlayer id App.Player.JoinSuccess
                    |> sendEvent
                , App.Host.PlayerJoined
                    { name = name
                    , players = Dict.values data.players |> List.map .name
                    }
                    |> ToHost
                    |> sendEvent
                ]
            )


handlePlayerAnswer sendEvent toSelf id fromPlayer data =
    let
        playerAlreadyAnswered =
            List.any (\{ playerId } -> playerId == id) data.answers
    in
    if playerAlreadyAnswered then
        ( WaitingForAnswers data
        , Cmd.none
        )

    else if fromPlayer.roundId /= data.round.id then
        ( WaitingForAnswers data
        , App.Player.AnswerWasTooLate
            |> ToPlayer id
            |> sendEvent
        )

    else
        let
            data2 =
                { data
                    | answers = { playerId = id, answer = fromPlayer.answer } :: data.answers
                }
        in
        if hasEveryoneAnswered data2 then
            endRound sendEvent toSelf data2

        else
            ( WaitingForAnswers data2
            , Cmd.none
            )


hasEveryoneAnswered data =
    data.answers
        |> List.foldl
            (\{ playerId } -> Dict.remove playerId)
            (Dict.filter (\_ p -> p.isConnected) data.players)
        |> Dict.isEmpty


handleHostEvent :
    (ToClient -> Cmd msg)
    -> (Msg -> msg)
    -> App.Host.ToServer
    -> Model
    -> ( Model, Cmd msg )
handleHostEvent sendEvent toSelf hostMsg model =
    case ( hostMsg, model ) of
        ( App.Host.CreateGame game, WaitingForGame ) ->
            ( WaitingForPlayers
                { occupiedNames = Set.empty
                , players = Dict.empty
                , game = game
                }
                |> Playing game
            , App.Host.GameCreated "123"
                |> ToHost
                |> sendEvent
            )

        ( App.Host.StartRound, Playing game (WaitingForPlayers data) ) ->
            case data.game.rounds of
                [] ->
                    ( model, Cmd.none )

                round :: rest ->
                    startRound
                        sendEvent
                        toSelf
                        data.players
                        round
                        rest
                        []
                        model
                        |> Tuple.mapFirst (Playing game)

        ( App.Host.StartRound, Playing game (DisplayingRoundResults data )) ->
            case data.upcomming of
                [] ->
                    endGame
                        sendEvent
                        toSelf
                        data.players
                        ({ round = data.round, scores = data.scores } :: data.completed)
                        model

                nextRound :: upcomming ->
                    startRound
                        sendEvent
                        toSelf
                        data.players
                        nextRound
                        upcomming
                        ({ round = data.round, scores = data.scores } :: data.completed)
                        model
                        |> Tuple.mapFirst (Playing game)

        ( App.Host.EndRound, Playing game (WaitingForAnswers data )) ->
            endRound sendEvent toSelf data
                |> Tuple.mapFirst (Playing game)

        ( App.Host.ShowOptionScreen fromGame, Playing game (WaitingForAnswers data )) ->
            ( model
            , App.Player.RoundStarted
                { roundId = fromGame.roundId
                , optionCount = fromGame.optionCount
                }
                |> broadcast
                    sendEvent
                    (Dict.keys data.players)
            )

        ( App.Host.ClearOptionScreen, Playing game (DisplayingRoundResults data )) ->
            ( model
            , App.Player.ClearOptionScreen
                |> broadcast
                    sendEvent
                    (Dict.keys data.players)
            )

        _ ->
            ( model
            , Cmd.none
            )


startRound sendEvent toSelf players round rest completed model =
    ( WaitingForAnswers
        { round = round
        , upcomming = rest
        , answers = []
        , completed = completed
        , players = players
        }
    , App.Host.RoundStarted round
        |> ToHost
        |> sendEvent
    )


endGame sendEvent toSelf players completed model =
    let
        scores =
            List.concatMap .scores completed
                |> sumScores players
    in
    ( WaitingForGame
    , Cmd.batch
        [ scores
            |> List.filterMap
                (\( playerId, score ) ->
                    Dict.get playerId players
                        |> Maybe.map
                            (\player ->
                                { name = playerName player
                                , score = score
                                }
                            )
                )
            |> App.Host.GameEnded
            |> ToHost
            |> sendEvent
        , scores
            |> List.sortBy Tuple.second
            |> List.reverse
            |> List.indexedMap
                (\idx ( player, score ) ->
                    App.Player.GameEnded (idx + 1)
                        |> ToPlayer player
                        |> sendEvent
                )
            |> Cmd.batch
        ]
    )


playerName player =
    if player.isConnected then
        player.name

    else
        player.name ++ " (left)"


broadcast sendEvent players msg =
    List.map
        (\id ->
            ToPlayer id msg
                |> sendEvent
        )
        players
        |> Cmd.batch


endRound sendEvent toSelf data =
    let
        scores =
            calculateScores data.round data.answers

        answerFreq =
            Dict.union
                (data.answers
                    |> List.map .answer
                    |> Dict.Extra.frequencies
                )
                (Dict.fromList
                    [ ( 0, 0 )
                    , ( 1, 0 )
                    , ( 2, 0 )
                    , ( 3, 0 )
                    ]
                )
                |> Dict.toList
    in
    ( DisplayingRoundResults
        { round = data.round
        , upcomming = data.upcomming
        , scores = scores
        , completed = data.completed
        , players = data.players
        }
    , { round = data.round
      , answerFreq = answerFreq
      , roundScores =
            scores
                |> List.filterMap
                    (\( playerId, score ) ->
                        Dict.get playerId data.players
                            |> Maybe.map
                                (\player ->
                                    { name = playerName player
                                    , score = score
                                    }
                                )
                    )
      , totalScores =
            List.concatMap .scores data.completed
                |> sumScores data.players
                |> List.filterMap
                    (\( playerId, score ) ->
                        Dict.get playerId data.players
                            |> Maybe.map
                                (\player ->
                                    { name = playerName player
                                    , score = score
                                    }
                                )
                    )
      }
        |> App.Host.RoundEnded
        |> ToHost
        |> sendEvent
    )


sumScores players completed =
    completed
        |> List.foldl
            (\( id, score ) dict ->
                Dict.update
                    id
                    (\mbScore ->
                        case mbScore of
                            Just s ->
                                Just (s + score)

                            Nothing ->
                                Just score
                    )
                    dict
            )
            (Dict.map (\_ _ -> 0) players)
        |> Dict.toList


calculateScores : Game.Round -> List PlayerAnswer -> List ( String, Int )
calculateScores round answers =
    let
        correctAnswers =
            round.options
                |> List.indexedMap Tuple.pair
                |> List.foldl
                    (\( idx, opt ) ->
                        if opt.isCorrect then
                            Set.insert idx

                        else
                            identity
                    )
                    Set.empty

        numCorrect =
            Set.size correctAnswers

        playersAnswered =
            List.length answers

        playerScores =
            answers
                |> List.filter
                    (\{ answer } ->
                        Set.member answer correctAnswers
                    )
                |> List.reverse
                |> List.indexedMap
                    (\idx { playerId } ->
                        ( playerId
                        , (2 * playersAnswered - idx) * (5 - numCorrect)
                        )
                    )
    in
    playerScores
