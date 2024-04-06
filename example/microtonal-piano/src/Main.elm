port module Main exposing (main)

import Color
import Json.Decode
import Json.Encode
import Random.Pcg.Extended
import Time
import Web
import Web.Audio
import Web.Audio.Parameter
import Web.Console
import Web.Dom
import Web.Http
import Web.Random
import Web.Time
import Web.Window


main : Web.Program State
main =
    Web.program
        { initialState = initialState
        , interface = interface
        , ports = { fromJs = fromJs, toJs = toJs }
        }


port toJs : Json.Encode.Value -> Cmd event_


port fromJs : (Json.Encode.Value -> event) -> Sub event


type State
    = State
        { windowSize : { width : Int, height : Int }
        , musicSource : Maybe (Result Web.AudioSourceLoadError Web.AudioSource)
        , tonesPlaying : List { time : Time.Posix, pitchPercentage : Float }
        , lastUnplayedClickPitchPercentage : Maybe Float
        }


type SoundSetting
    = SoundOn
    | SoundOff


codeRandomGenerator : Random.Pcg.Extended.Generator Int
codeRandomGenerator =
    Random.Pcg.Extended.int 100 500


initialState : State
initialState =
    State
        { windowSize = { width = 1920, height = 1080 } -- dummy
        , musicSource = Nothing
        , tonesPlaying = []
        , lastUnplayedClickPitchPercentage = Nothing
        }


interface : State -> Web.Interface State
interface =
    \(State state) ->
        [ [ Web.Window.sizeRequest, Web.Window.resizeListen ]
            |> Web.interfaceBatch
            |> Web.interfaceFutureMap (\windowSize -> State { state | windowSize = windowSize })
        , case state.musicSource of
            Just (Err _) ->
                Web.Console.error "audio failed to load"

            Just (Ok musicSource) ->
                [ case state.lastUnplayedClickPitchPercentage of
                    Nothing ->
                        Web.interfaceNone

                    Just pitchPercentage ->
                        Web.Time.posixRequest
                            |> Web.interfaceFutureMap
                                (\time ->
                                    State
                                        { state
                                            | tonesPlaying =
                                                state.tonesPlaying
                                                    |> (::) { time = time, pitchPercentage = pitchPercentage }
                                            , lastUnplayedClickPitchPercentage = Nothing
                                        }
                                )
                , state.tonesPlaying
                    |> List.map
                        (\tonePlaying ->
                            Web.Audio.fromSource musicSource tonePlaying.time
                                |> Web.Audio.volumeScaleBy (Web.Audio.Parameter.at 0.6)
                                |> Web.Audio.speedScaleBy
                                    (Web.Audio.Parameter.at (2 ^ (((tonePlaying.pitchPercentage - 0.5) * 36) / 12)))
                                |> Web.Audio.play
                        )
                    |> Web.interfaceBatch
                ]
                    |> Web.interfaceBatch

            Nothing ->
                Web.Audio.sourceLoad "piano-C5.mp3"
                    |> Web.interfaceFutureMap
                        (\result -> State { state | musicSource = result |> Just })
        , Web.Dom.element "div"
            [ Web.Dom.style "background-color" (Color.rgb 0 0 0 |> Color.toCssString)
            , Web.Dom.style "color" (Color.rgb 1 1 1 |> Color.toCssString)
            , Web.Dom.style "position" "fixed"
            , Web.Dom.style "top" "0"
            , Web.Dom.style "right" "0"
            , Web.Dom.style "bottom" "0"
            , Web.Dom.style "left" "0"
            , Web.Dom.listenTo "click"
                |> Web.Dom.modifierFutureMap
                    (\clickJson ->
                        clickJson
                            |> Json.Decode.decodeValue
                                (Json.Decode.field "clientY" Json.Decode.float)
                    )
                |> Web.Dom.modifierFutureMap
                    (\clientYResult ->
                        case clientYResult of
                            Err _ ->
                                State state

                            Ok clientY ->
                                State
                                    { state
                                        | lastUnplayedClickPitchPercentage =
                                            (1 - clientY / (state.windowSize.height |> Basics.toFloat)) |> Just
                                    }
                    )
            ]
            [ Web.Dom.element "table"
                [ Web.Dom.style "width" "100%"
                , Web.Dom.style "height" "100%"
                , Web.Dom.style "position" "absolute"
                , Web.Dom.style "z-index" "1"
                ]
                (List.range 0 31
                    |> List.map
                        (\i ->
                            Web.Dom.element "tr"
                                [ Web.Dom.style "background"
                                    (Color.rgba 0
                                        1
                                        1
                                        ((i |> Basics.remainderBy 12 |> Basics.toFloat) / 12)
                                        |> Color.toCssString
                                    )
                                ]
                                [ Web.Dom.element "th"
                                    []
                                    []
                                ]
                        )
                )
            , Web.Dom.element "div"
                [ Web.Dom.style "font-size" "3em"
                , Web.Dom.style "padding" "1%"
                , Web.Dom.style "margin" "auto"
                , Web.Dom.style "width" "50%"
                , Web.Dom.style "position" "relative"
                , Web.Dom.style "user-select" "none"
                , Web.Dom.style "text-align" "center"
                , Web.Dom.style "z-index" "2"
                , Web.Dom.style "background-color" (Color.rgba 0 0 0 0.5 |> Color.toCssString)
                ]
                [ Web.Dom.element "b" [] [ Web.Dom.text "click height = note pitch" ]
                ]
            ]
            |> Web.Dom.render
        ]
            |> Web.interfaceBatch


buttonUi : List (Web.Dom.Modifier ()) -> List (Web.Dom.Node ()) -> Web.Dom.Node ()
buttonUi modifiers subs =
    Web.Dom.element "button"
        ([ Web.Dom.listenTo "click"
            |> Web.Dom.modifierFutureMap (\_ -> ())
         , Web.Dom.style "background-color" "#000000"
         , Web.Dom.style "border-top" "none"
         , Web.Dom.style "border-left" "none"
         , Web.Dom.style "border-right" "none"
         , Web.Dom.style "border-bottom" ("6px solid " ++ (Color.rgba 1 1 1 0.4 |> Color.toCssString))
         , Web.Dom.style "border-radius" "20px"
         , Web.Dom.style "color" "#FFFFFF"
         , Web.Dom.style "padding" "6px 15px"
         , Web.Dom.style "margin" "0px 0px"
         , Web.Dom.style "text-align" "center"
         , Web.Dom.style "display" "inline-block"
         , Web.Dom.style "font-family" "inherit"
         ]
            ++ modifiers
        )
        subs
