module Game exposing (..)

import Set exposing (Set)


type alias Game =
    { title : String
    , rounds : List Round
    }


type alias Round =
    { id : String
    , question : String
    , options : List Option
    }


type alias Option =
    { answer : String
    , isCorrect : Bool
    }


test : Game
test =
    { title = "My game"
    , rounds =
        [ { id = "1"
          , question = "Question 1"
          , options =
                [ { isCorrect = False, answer = "One" }
                , { isCorrect = True, answer = "Two" }
                , { isCorrect = False, answer = "Three" }
                , { isCorrect = False, answer = "Four" }
                ]
          }
        , { id = "2"
          , question = "Question 2"
          , options =
                [ { isCorrect = False, answer = "One" }
                , { isCorrect = True, answer = "Two" }
                , { isCorrect = False, answer = "Three" }
                , { isCorrect = False, answer = "Four" }
                ]
          }
        ]
    }


