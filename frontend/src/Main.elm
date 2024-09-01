module Main exposing (..)

import Browser
import Debug


type alias Model =
    Maybe Int


type Msg
    = Select Int
    | Update Int


init =
    Debug.todo "init"


view =
    Debug.todo "view"


update =
    Debug.todo "update"


main : Program Int Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }
