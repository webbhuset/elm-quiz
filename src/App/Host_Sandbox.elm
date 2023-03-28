module App.Host_Sandbox exposing (..)

import App.Host
import Browser
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as Events
import Design
import Process
import Task


type Msg
    = Msg App.Host.Msg
    | Tick


main : Program () Bool Msg
main =
    Browser.sandbox
        { init = init
        , update = update
        , view = view
        }


init =
    False


update msg model =
    case msg of
        Tick ->
            not model

        _ ->
            model


view bool =
    Html.div
        [ HA.class "flex-col"
        , HA.style "padding" "1em"
        ]
        [ Design.stylesheet "/src/Build/common.css"
        , Design.stylesheet "/src/Build/host.css"
        , Design.stylesheet "/src/Build/dev.css"
        , Html.div
            [ HA.class "flex-row w-full fixed"
            , HA.style "top" "0"
            , HA.style "left" "0"
            , HA.style "background" "white"
            , HA.style "padding" "0.5em"
            , HA.style "z-index" "1"
            ]
            [ Html.button
                [ Events.onClick Tick
                ]
                [ Html.text "Toggle animation"
                ]
            ]
        , Html.div
            [ HA.class "flex-col dev-game"
            , HA.style "row-gap" "1em"
            , HA.style "margin-top" "2em"
            ]
            (models bool
                |> List.map
                    (\model ->
                        App.Host.view model
                    )
            )
            |> Html.map Msg
        ]


models bool =
    [ App.Host.ChooseGame
        { url = ""
        , games =
            [ { title = "The frontend quiz", rounds = [] }
            , { title = "The backend quiz", rounds = [] }
            , { title = "The project manager quiz", rounds = [] }
            ]
        }
    , App.Host.WaitingForPlayers
        { url = "http://example.com"
        , players = []
        }
    , App.Host.WaitingForPlayers
        { url = "http://example.com"
        , players =
            [ "Player 1"
            , "Player 2"
            , "Player with a really long name 1"
            , "Player 4"
            , "Player 5"
            , "Player with a really long name 2"
            , "Player 3"
            ]
        }
    , App.Host.JustGotPlayer
        { url = "http://example.com"
        , name = "The new player"
        , players = 
            [ "Player 1"
            , "Player 2"
            , "Player with a really long name 1"
            , "Player 4"
            , "Player 5"
            , "Player with a really long name 2"
            , "Player 3"
            ]
        }
    , App.Host.WaitingForGameStart
    , App.Host.Countdown 3 round3
    , App.Host.ShowQuestion round4
    , App.Host.ShowQuestion round3
    , App.Host.ShowQuestion round2
    , App.Host.ShowRoundResults bool
        { results
            | answerFreq =
                [ ( 0, 1 )
                , ( 1, 1 )
                , ( 2, 1 )
                , ( 3, 1 )
                ]
        }
    , App.Host.ShowRoundResults bool
        { results
            | answerFreq =
                [ ( 0, 10 )
                , ( 1, 0 )
                , ( 2, 0 )
                , ( 3, 0 )
                ]
        }
    , App.Host.ShowLeaderboard bool results
    , App.Host.ShowWinner results.totalScores
    ]


results =
    { round = round4
    , roundScores =
        [ { name = "Player 1", score = 1000 }
        , { name = "Player 2", score = 2000 }
        , { name = "Player 3", score = 3000 }
        ]
    , totalScores =
        { name = "A player with a long name"
        , score = 2800
        }
            :: (List.range 1 30
                    |> List.map
                        (\n ->
                            { name = "Player " ++ String.fromInt n
                            , score = n * 100
                            }
                        )
               )
    , answerFreq =
        [ ( 0, 1 )
        , ( 1, 0 )
        , ( 2, 10 )
        , ( 3, 3 )
        ]
    }


round4 =
    { id = ""
    , question = "This is a question with 4 options"
    , options =
        [ { isCorrect = False, answer = "This is the first answer" }
        , { isCorrect = True, answer = "This is the second answer (also the correct)" }
        , { isCorrect = False, answer = "This is the third answer" }
        , { isCorrect = False, answer = "This is the fourth answer" }
        ]
    }


round3 =
    { id = ""
    , question = "This is a question with 3 options"
    , options =
        [ { isCorrect = False, answer = "Option one" }
        , { isCorrect = True, answer = "Option two" }
        , { isCorrect = False, answer = "Option three" }
        ]
    }


round2 =
    { id = ""
    , question = "This is a question with 2 options"
    , options =
        [ { isCorrect = False, answer = "Option one" }
        , { isCorrect = True, answer = "Option two" }
        ]
    }
