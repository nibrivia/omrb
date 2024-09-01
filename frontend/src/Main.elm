module Main exposing (..)

import Browser
import Debug
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List.Extra as List


type alias Model =
    { nButtons : Int
    , checkedButton : Maybe Int
    }


type Msg
    = Select Int
    | Update Int


init : Int -> ( Model, Cmd Msg )
init nButtons =
    ( { nButtons = nButtons
      , checkedButton = Nothing
      }
    , Cmd.none
    )


view : Model -> Html Msg
view model =
    let
        buttons : List (Html Msg)
        buttons =
            List.range 0 model.nButtons
                |> List.reverseMap
                    (\buttonIx ->
                        Html.input
                            [ Html.Attributes.name "omrb"
                            , Html.Attributes.type_ "radio"
                            , Html.Attributes.id ("omrb-" ++ String.fromInt buttonIx)
                            , onCheck
                                (\checked ->
                                    if checked then
                                        Select buttonIx

                                    else
                                        Select buttonIx
                                )
                            , Html.Attributes.checked (Just buttonIx == model.checkedButton)
                            ]
                            []
                    )
                |> List.reverse
    in
    Html.div
        [ Html.Attributes.id "omrb" ]
        buttons


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Select checkedIx ->
            ( { model | checkedButton = Just checkedIx }, Cmd.none )

        Update checkedIx ->
            ( { model | checkedButton = Just checkedIx }, Cmd.none )


main : Program Int Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }
