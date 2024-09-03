port module Main exposing (..)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List.Extra as List


type alias Model =
    { nButtons : Int
    , checkedButton : Maybe Int
    }


type Msg
    = UserSelected Int
    | ServerUpdate Int
    | Noop


init : Int -> ( Model, Cmd Msg )
init nButtons =
    ( { nButtons = nButtons
      , checkedButton = Nothing
      }
    , Cmd.none
    )


port sendMessage : String -> Cmd msg


port messageReceiver : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    messageReceiver
        (\newRB ->
            newRB
                |> String.toInt
                |> Maybe.map ServerUpdate
                |> Maybe.withDefault Noop
        )


makeButton : Maybe Int -> Int -> Html Msg
makeButton checkedIx buttonIx =
    let
        name =
            "omrb-" ++ String.fromInt buttonIx
    in
    Html.label
        [ Html.Attributes.for name ]
        [ Html.input
            [ Html.Attributes.name "omrb"
            , Html.Attributes.type_ "radio"
            , Html.Attributes.id name
            , onCheck
                (\checked ->
                    if checked then
                        UserSelected buttonIx

                    else
                        UserSelected buttonIx
                )
            , Html.Attributes.checked (Just buttonIx == checkedIx)
            ]
            []
        ]


view : Model -> Html Msg
view model =
    let
        buttons : List (Html Msg)
        buttons =
            List.range 0 model.nButtons
                -- for large lists, reverseMap >> reverse is much more memory efficient
                |> List.reverseMap (makeButton model.checkedButton)
                |> List.reverse
    in
    Html.div
        [ Html.Attributes.id "omrb" ]
        buttons


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UserSelected checkedIx ->
            ( { model | checkedButton = Just checkedIx }
            , checkedIx |> String.fromInt |> sendMessage
            )

        ServerUpdate checkedIx ->
            ( { model | checkedButton = Just checkedIx }
            , Cmd.none
            )

        Noop ->
            ( model, Cmd.none )


main : Program Int Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
