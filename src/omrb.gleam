import gleam/bytes_builder
import gleam/erlang/process.{type Subject}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import mist.{type ResponseData}
import nakai
import nakai/attr
import nakai/html

pub fn main() {
  io.println("Hello from omrb!")

  let assert Ok(state_actor) = actor.start(State(None), handle_message)

  let assert Ok(_) =
    fn(_request) {
      let selected_ix = process.call(state_actor, Value, 50)
      make_page(selected_ix)
      |> bytes_builder.from_string
      |> mist.Bytes
      |> to_html_response
    }
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

const n_buttons = 10_000

type State {
  State(selected: Option(Int))
}

type Action {
  Select(Int)
  Value(reply_with: Subject(Option(Int)))
}

fn handle_message(msg: Action, state: State) -> actor.Next(Action, State) {
  let State(selected_ix) = state
  case msg {
    Select(button_ix) -> {
      case 0 <= button_ix && button_ix < n_buttons {
        True -> actor.continue(State(Some(button_ix)))
        _ -> actor.continue(state)
      }
    }
    Value(client) -> {
      process.send(client, selected_ix)
      actor.continue(state)
    }
  }
}

fn make_page(selected_ix: Option(Int)) -> String {
  let buttons =
    list.repeat(
      html.input([attr.type_("radio"), attr.name("omrb")]),
      times: n_buttons,
    )
  html.Html([], [
    html.Head([html.title("One Million Radio Buttons")]),
    html.Body(
      [],
      [
        html.h1_text([], "One Million Radio Buttons"),
        html.p_text(
          [],
          "Welcome! This is deeply inspired by One Million Checkboxes",
        ),
      ]
        |> list.append(buttons),
    ),
  ])
  |> nakai.to_string
}

fn to_html_response(data: ResponseData) -> Response(ResponseData) {
  response.new(200)
  |> response.set_body(data)
  |> response.set_header("content-type", "text/html")
}
