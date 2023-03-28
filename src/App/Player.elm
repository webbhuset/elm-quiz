module App.Player exposing (..)

import Design
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as Events


type Msg
    = NameChanged String
    | JoinClicked
    | GotServerMsg FromServer
    | AnswerClicked Int
    | GotSocketMsg SocketMsg


type SocketMsg
    = SocketClose
    | SocketError


type ToServer
    = JoinGame String
    | SelectAnswer SelectAnswerMsg


type alias SelectAnswerMsg =
    { roundId : String
    , answer : Int
    }


type FromServer
    = JoinSuccess
    | JoinFail JoinFailMsg
    | RoundStarted RoundStartedMsg
    | AnswerWasTooLate
    | ClearOptionScreen
    | GameEnded Int
    | GameNotFound


type alias RoundStartedMsg =
    { roundId : String
    , optionCount : Int
    }


type alias JoinFailMsg =
    { reason : String
    , name : String
    }


type Model
    = EnterName
        { name : String
        , error : Maybe String
        }
    | WaitForJoinConfirmation
    | WaitForRoundStart
    | ChooseAnswer String Int
    | AnswerSelected Int Int
    | DisplayError String
    | FinishedAt Int


init : Model
init =
    EnterName { name = "", error = Nothing }


update : (ToServer -> Cmd msg) -> (Msg -> msg) -> Msg -> Model -> ( Model, Cmd msg )
update sendEvent toSelf msg model =
    case ( msg, model ) of
        ( GotSocketMsg SocketError, _ ) ->
            ( DisplayError "Socket error"
            , Cmd.none
            )

        ( GotSocketMsg SocketClose, DisplayError _ ) ->
            ( model
            , Cmd.none
            )

        ( GotSocketMsg SocketClose, _ ) ->
            ( DisplayError "Connection closed"
            , Cmd.none
            )

        ( NameChanged name, EnterName data ) ->
            ( EnterName { data | name = name }
            , Cmd.none
            )

        ( JoinClicked, EnterName data ) ->
            ( WaitForJoinConfirmation
            , JoinGame data.name
                |> sendEvent
            )

        ( GotServerMsg JoinSuccess, WaitForJoinConfirmation ) ->
            ( WaitForRoundStart
            , Cmd.none
            )

        ( GotServerMsg (JoinFail args), WaitForJoinConfirmation ) ->
            ( EnterName { name = args.name, error = Just args.reason }
            , Cmd.none
            )

        ( GotServerMsg (RoundStarted args), _ ) ->
            ( ChooseAnswer args.roundId args.optionCount
            , Cmd.none
            )

        ( AnswerClicked answer, ChooseAnswer roundId count ) ->
            ( AnswerSelected answer count
            , SelectAnswer
                { roundId = roundId
                , answer = answer
                }
                |> sendEvent
            )

        ( GotServerMsg AnswerWasTooLate, AnswerSelected _ _ ) ->
            ( DisplayError "Sorry, too late :("
            , Cmd.none
            )

        ( GotServerMsg ClearOptionScreen, _ ) ->
            ( WaitForRoundStart
            , Cmd.none
            )

        ( GotServerMsg (GameEnded pos), _ ) ->
            ( FinishedAt pos
            , Cmd.none
            )

        _ ->
            ( model
            , Cmd.none
            )


view : Model -> Html Msg
view model =
    Html.div
        [ HA.class "flex-col items-center justify-center h-full player-screen"
        ]
        [ case model of
            EnterName data ->
                view_EnterName data

            WaitForJoinConfirmation ->
                Html.text "Joining..."

            WaitForRoundStart ->
                Html.text "Waiting for round to start"

            ChooseAnswer _ count ->
                view_ChooseAnswer Nothing count

            AnswerSelected n count ->
                view_ChooseAnswer (Just n) count

            DisplayError err ->
                view_Error err

            FinishedAt pos ->
                view_Finish pos
        ]


view_EnterName : { name : String, error : Maybe String } -> Html Msg
view_EnterName data =
    Html.div
        [ HA.class "flex-col justify-center h-full"
        ]
        [ Html.label
            [ HA.class "flex-col"
            , HA.style "row-gap" "0.25em"
            , HA.style "padding" "2em"
            ]
            [ Html.div [] [ Html.text "Enter you name" ]
            , Html.div
                [ HA.class "flex-row"
                ]
                [ Html.input
                    [ HA.value data.name
                    , Events.onInput NameChanged
                    ]
                    []
                , Html.button
                    [ Events.onClick JoinClicked
                    ]
                    [ Html.text "Join"
                    ]
                ]
            , case data.error of
                Just error ->
                    Html.div
                        [ HA.style "color" "#E00"
                        ]
                        [ Html.text error
                        ]

                Nothing ->
                    Html.div [] []
            ]
        , Html.div
            [ HA.style "height" "30%"
            ]
            []
        ]


view_ChooseAnswer : Maybe Int -> Int -> Html Msg
view_ChooseAnswer selected count =
    List.range 0 (count - 1)
        |> List.map
            (\n ->
                Design.answerBlock
                    [ Events.onClick (AnswerClicked n)
                    , Design.colorClass n
                    , HA.disabled (not <| selected == Nothing)
                    , if Just n == selected then
                        HA.style "outline-style" "solid"

                      else
                        HA.style "outline" "none"
                    , if selected == Nothing || Just n == selected then
                        HA.style "opacity" "1"

                      else
                        HA.style "opacity" "0.2"
                    ]
                    n
            )
        |> Html.div
            [ HA.class "grid col-2 w-full"
            , HA.style "padding" "1em"
            , HA.style "gap" "1em"
            ]


view_Error : String -> Html msg
view_Error err =
    Html.div
        []
        [ Html.text err
        ]


view_Finish : Int -> Html msg
view_Finish pos =
    Html.div
        [ HA.class "flex-col items-center"
        ]
        (case pos of
            1 ->
                [ Html.div [] [ Html.text "You finished first!" ]
                , Html.div [] [ Html.text "Congratulations!!" ]
                ]

            2 ->
                [ Html.text "You finished second place!"
                ]

            3 ->
                [ Html.text "You finished on 3rd place"
                ]

            _ ->
                [ Html.text ("You finished at position " ++ String.fromInt pos)
                ]
        )
