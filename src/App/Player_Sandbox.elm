module App.Player_Sandbox exposing (..)

import App.Player
import Browser
import Design
import Html exposing (Html)
import Html.Attributes as HA
import Html.Events as Events


main : Html App.Player.Msg
main =
    Html.div
        [ HA.class "flex-col"
        , HA.style "padding" "1em"
        , HA.style "row-gap" "1em"
        ]
        [ Design.stylesheet "/src/Build/common.css"
        , Design.stylesheet "/src/Build/player.css"
        , Design.stylesheet "/src/Build/dev.css"
        , Html.div
            [ HA.class "grid dev-player-grid"
            ]
            (models
                |> List.map
                    (\player ->
                        App.Player.view player
                    )
            )
        ]


models =
    [ App.Player.EnterName
        { name = ""
        , error = Nothing
        }
    , App.Player.EnterName
        { name = "My name"
        , error = Nothing
        }
    , App.Player.EnterName
        { name = "My name"
        , error = Just "Name is already taken"
        }
    , App.Player.WaitForJoinConfirmation
    , App.Player.WaitForRoundStart
    , App.Player.ChooseAnswer "" 2
    , App.Player.ChooseAnswer "" 3
    , App.Player.ChooseAnswer "" 4
    , App.Player.AnswerSelected 1 4
    , App.Player.DisplayError "Some error message"
    , App.Player.FinishedAt 1
    , App.Player.FinishedAt 2
    , App.Player.FinishedAt 3
    , App.Player.FinishedAt 4
    ]
