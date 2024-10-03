port module Main exposing (..)

import Browser
import Browser.Dom as Dom
import Browser.Events as Events
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy as Lazy
import Json.Decode as Decode
import List.Extra as List
import Task


type alias Model =
    { nButtons : Int
    , checkedIx : Maybe Int
    , viewWidth : Int
    , viewHeight : Int
    , viewOffset : Int
    }


type Msg
    = UserSelected Int
    | ServerUpdate Int
    | GetNewViewport
    | NewViewport Dom.Viewport
    | Noop


type alias ButtonData =
    { ix : Int
    , row : Int
    , col : Int
    , isChecked : Bool
    }


buttonWidth : Int
buttonWidth =
    24


rowHeight : Int
rowHeight =
    24


init : Int -> ( Model, Cmd Msg )
init nButtons =
    ( { nButtons = nButtons
      , checkedIx = Nothing
      , viewWidth = 500
      , viewHeight = 700
      , viewOffset = 0
      }
    , Task.perform NewViewport Dom.getViewport
    )


port sendMessage : String -> Cmd msg


port onScroll : (String -> msg) -> Sub msg


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
    , onScroll (\_ -> GetNewViewport)
    ]
        |> Sub.batch


makeButton : ButtonData -> Html Msg
makeButton { isChecked, ix, row, col } =
    let
        name =
            "omrb-" ++ String.fromInt ix

        pos_x =
            col * buttonWidth

        pos_y =
            row * rowHeight
    in
    Html.label
        [ Html.Attributes.for name
        , Html.Attributes.style "position" "absolute"
        , Html.Attributes.style "left" (String.fromInt pos_x ++ "px")
        , Html.Attributes.style "top" (String.fromInt pos_y ++ "px")
        ]
        [ Html.input
            [ Html.Attributes.name "omrb"
            , Html.Attributes.type_ "radio"
            , Html.Attributes.id name
            , onCheck
                (\checked ->
                    if checked then
                        UserSelected ix

                    else
                        UserSelected ix
                )
            , Html.Attributes.checked isChecked
            ]
            []
        ]


buttonViewer : { a | viewWidth : Int, viewHeight : Int, viewOffset : Int, nButtons : Int, checkedIx : Maybe Int } -> Html Msg
buttonViewer { viewWidth, nButtons, checkedIx, viewHeight, viewOffset } =
    let
        nPerRow : Int
        nPerRow =
            (toFloat (viewWidth - 10) / toFloat buttonWidth)
                |> floor

        nRows : Int
        nRows =
            (toFloat nButtons / toFloat nPerRow)
                |> ceiling

        firstVisibleRow =
            viewOffset // rowHeight

        nVisibleRows =
            round (toFloat viewHeight / toFloat rowHeight)

        lastVisibleRow =
            firstVisibleRow + nVisibleRows

        firstIx =
            (firstVisibleRow - 10) * nPerRow

        lastIx =
            (lastVisibleRow + 10) * nPerRow
    in
    Html.div
        [ Html.Attributes.style "height" ((nRows * rowHeight |> String.fromInt) ++ "px")
        , Html.Attributes.style "width" ((nPerRow * buttonWidth |> String.fromInt) ++ "px")
        , Html.Attributes.style "margin" "0"
        , Html.Attributes.style "padding" "0"
        , Html.Attributes.style "position" "relative"
        , Html.Attributes.style "overflow" "scroll"
        , Html.Attributes.style "border" "3px solid red"
        , Html.Events.on "scroll" (Decode.succeed GetNewViewport)
        ]
        (List.range firstIx lastIx
            -- for large lists, reverseMap >> reverse is much more memory efficient
            |> List.reverseMap
                (\ix ->
                    let
                        buttonData =
                            { ix = ix
                            , isChecked = checkedIx == Just ix
                            , row = ix // nPerRow
                            , col = modBy nPerRow ix
                            }
                    in
                    makeButton buttonData
                )
            |> List.reverse
        )


view : Model -> Html Msg
view model_ =
    Lazy.lazy
        (\model ->
            let
                buttons : Html Msg
                buttons =
                    buttonViewer model
            in
            Html.div
                [ Html.Attributes.id "omrb-elm" ]
                [ buttons ]
        )
        model_


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

        GetNewViewport ->
            ( model, Task.perform NewViewport Dom.getViewport )

        NewViewport viewport ->
            ( { model
                | viewWidth = round viewport.viewport.width
                , viewHeight = round viewport.viewport.height
                , viewOffset = round viewport.viewport.y
              }
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
