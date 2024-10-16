port module Main exposing (..)

import Browser
import Browser.Dom as Dom
import Browser.Events as Events
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed
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
    , Events.onResize (\_ _ -> GetNewViewport)
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


type CheckedDirection
    = Above
    | Visible
    | Below


buttonViewer : Model -> Html Msg
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
            Basics.max 0 ((firstVisibleRow - 10) * nPerRow)

        lastIx =
            Basics.min (nButtons - 1) ((lastVisibleRow + 10) * nPerRow)

        checkboxes =
            Html.Keyed.node
                "div"
                [ Html.Attributes.style "height" ((nRows * rowHeight |> String.fromInt) ++ "px")
                , Html.Attributes.style "width" ((nPerRow * buttonWidth |> String.fromInt) ++ "px")
                , Html.Attributes.style "margin" "0"
                , Html.Attributes.style "padding" "0"
                , Html.Attributes.style "position" "relative"
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
                            -- (key, button)
                            ( String.fromInt ix, makeButton buttonData )
                        )
                    |> List.reverse
                )

        -- TODO: this whole section is way hacky, clean it up
        checkedDirection =
            checkedIx
                |> Maybe.map
                    (\cIx ->
                        if cIx < firstIx then
                            Above

                        else if cIx > lastIx then
                            Below

                        else
                            Visible
                    )

        arrow =
            let
                checkedPos =
                    checkedIx
                        |> Maybe.map (\ix -> ix |> modBy nPerRow |> (*) buttonWidth)
            in
            case checkedDirection of
                Just Above ->
                    Html.div
                        [ Html.Attributes.style "position" "fixed"
                        , Html.Attributes.style "top" "-10px"
                        , Html.Attributes.style "left" (String.fromInt (checkedPos |> Maybe.withDefault 0) ++ "px")
                        , Html.Attributes.style "text-align" "center"
                        , Html.Attributes.style "width" (String.fromInt (1 * buttonWidth) ++ "px")
                        , Html.Attributes.style "height" "0em"
                        , Html.Attributes.style "box-shadow" "0px 20px 20px 10px #66339966"
                        ]
                        []

                Just Below ->
                    Html.div
                        [ Html.Attributes.style "position" "fixed"
                        , Html.Attributes.style "bottom" "-10px"
                        , Html.Attributes.style "left" (String.fromInt (checkedPos |> Maybe.withDefault 0) ++ "px")
                        , Html.Attributes.style "text-align" "center"
                        , Html.Attributes.style "width" (String.fromInt (1 * buttonWidth) ++ "px")
                        , Html.Attributes.style "height" "0em"
                        , Html.Attributes.style "box-shadow" "0px -10px 20px 20px #66339966"
                        ]
                        []

                _ ->
                    Html.div [] []
    in
    Html.div
        []
        [ arrow
        , checkboxes
        , Html.p
            [ Html.Attributes.style "text-align" "right"
            , Html.Attributes.style "font-family" "monospace"
            , Html.Attributes.style "max-width" "100%"
            ]
            [ Html.text "Made with fun, for fun, using Elm and Gleam fun(). "
            , Html.a
                [ Html.Attributes.href "https://github.com/nibrivia/omrb" ]
                [ Html.text "Check it out!" ]
            ]
        ]


view : Model -> Html Msg
view model =
    let
        buttons : Html Msg
        buttons =
            buttonViewer model
    in
    Html.div
        [ Html.Attributes.id "omrb-elm" ]
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
