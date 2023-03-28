module Design exposing (..)

import Html exposing (Html)
import Html.Attributes as HA


stylesheet : String -> Html msg
stylesheet src =
    Html.node "link"
        [ HA.rel "stylesheet"
        , HA.href src
        ]
        []


colorClass : Int -> Html.Attribute msg
colorClass n =
    HA.class ("color-answer-" ++ String.fromInt n)


answerBlock attr n =
    Html.button
        (HA.class "answer"
            :: attr
        )
        [ Html.text (String.fromInt (n + 1))
        ]


bar tick total answer freq =
    Html.div
        [ HA.class "bar relative"
        , HA.classList
            [ ( "bar-frame-end", tick )
            ]
        , colorClass answer
        , if tick then
            HA.style "height" (String.fromFloat (100 * toFloat freq / total) ++ "%")

          else
            HA.style "height" "0%"
        ]
        [ Html.div
            [ HA.style "position" "relative"
            , HA.style "top" "-1.2em"
            ]
            [ Html.text (String.fromInt freq)
            ]
        ]
