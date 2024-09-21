port module Main exposing (..)

import Browser
import Browser.Dom as Dom
import Browser.Events as Events
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List.Extra as List
import Task


type alias Model =
    { nButtons : Int
    , checkedIx : Maybe Int
    , viewWidth : Int
    , viewHeight : Int
    , viewOffset: Int
    }


type Msg
    = UserSelected Int
    | ServerUpdate Int
    | NewWidth Int
    | Noop


init : Int -> ( Model, Cmd Msg )
init nButtons =
    ( { nButtons = nButtons
      , checkedIx = Nothing
      , viewWidth = 500
      , viewHeight = 700
      , viewOffset = 0
      }
    , Task.perform updateWidth Dom.getViewport
    )


updateWidth : Dom.Viewport -> Msg
updateWidth viewPort =
    NewWidth (viewPort.viewport.width |> round)


port sendMessage : String -> Cmd msg


port messageReceiver : (String -> msg) -> Sub msg


subscriptions : Model -> Sub Msg
subscriptions _ =
    [ messageReceiver
        (\newRB ->
            newRB
                |> String.toInt
                |> Maybe.map ServerUpdate
                |> Maybe.withDefault Noop
        )
    , Events.onResize (\w _ -> NewWidth w)
    ] |> Sub.batch


makeButton : Bool -> Int -> Html Msg
makeButton isChecked buttonIx =
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
            , Html.Attributes.checked isChecked
            ]
            []
        ]


buttonViewer : { a | viewWidth : Int, viewHeight: Int, viewOffset: Int, nButtons : Int, checkedIx : Maybe Int } -> Html Msg
buttonViewer { viewWidth, nButtons, checkedIx } =
    let
        nPerRow : Int
        nPerRow =
            (toFloat viewWidth / toFloat buttonWidth)
                |> floor

        nRows : Int
        nRows =
            (toFloat nButtons / toFloat nPerRow)
                |> ceiling

        buttonWidth : Int
        buttonWidth =
            24

        rowHeight =
            24
    in
    Html.div
        [ Html.Attributes.style "height" ((nRows * rowHeight |> String.fromInt) ++ "px")
        , Html.Attributes.style "width" ((nPerRow * buttonWidth |> String.fromInt) ++ "px")
        , Html.Attributes.style "margin" "0"
        , Html.Attributes.style "padding" "0"
        , Html.Attributes.style "border" "3px solid red"
        ]
        (List.range 1 nButtons
            -- for large lists, reverseMap >> reverse is much more memory efficient
            |> List.reverseMap (\ix -> makeButton (checkedIx == Just ix) ix)
            |> List.reverse
        )


view : Model -> Html Msg
view model =
    let
        buttons : Html Msg
        buttons =
            buttonViewer model
    in
    Html.div
        [ Html.Attributes.id "omrb" ]
        [ buttons ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UserSelected checkedIx ->
            ( { model | checkedIx = Just checkedIx }
            , checkedIx |> String.fromInt |> sendMessage
            )

        ServerUpdate checkedIx ->
            ( { model | checkedIx = Just checkedIx }
            , Cmd.none
            )

        NewWidth width ->
            ( { model | viewWidth = width }
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
