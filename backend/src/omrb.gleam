import gleam/bytes_builder
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import mist.{type Connection, type ResponseData}
import nakai
import nakai/attr
import nakai/html

const n_buttons = 10_000

type State {
  State(selected: Option(Int))
}

type Action {
  Select(Int)
  Value(reply_with: Subject(Option(Int)))
}

pub fn main() {
  let selected_subject: process.Subject(State) = process.new_subject()

  let homepage =
    make_page()
    |> bytes_builder.from_string
    |> mist.Bytes
    |> to_html_response

  let assert Ok(_) =
    fn(request) {
      case request.path_segments(request) {
        ["elm.js"] -> {
          mist.send_file("../frontend/assets/elm.js", offset: 0, limit: None)
          |> result.map(fn(file) {
            let content_type = "text/javascript"

            response.new(200)
            |> response.prepend_header("content-type", content_type)
            |> response.set_body(file)
          })
          |> result.unwrap(homepage)
        }

        ["ws"] -> {
          mist.websocket(
            request: request,
            on_init: fn(_conn) {
              #(
                selected_subject,
                process.new_selector()
                  |> process.selecting(selected_subject, function.identity)
                  |> Some,
              )
            },
            on_close: fn(_state) { Nil },
            handler: handle_ws_update,
          )
        }
        _ -> homepage
      }
    }
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

fn handle_ws_update(state: process.Subject(State), conn, message) {
  io.debug(state)
  io.debug(conn)
  io.debug(message)
  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(state)
    }
    mist.Text(str) -> {
      // TODO 
      case str |> int.parse |> result.then(is_valid_index) {
        Ok(num) -> {
          io.debug(num)
          process.send(state, State(Some(num)))
          actor.continue(state)
        }

        _ -> actor.continue(state)
      }
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
    _ -> actor.continue(state)
  }
}

fn is_valid_index(box_ix: Int) -> Result(Int, Nil) {
  case 0 <= box_ix && box_ix < n_buttons {
    True -> Ok(box_ix)
    _ -> Error(Nil)
  }
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

fn make_page() -> String {
  html.Html([], [
    html.Head([
      html.title("One Million Radio Buttons"),
      html.Element("script", [attr.src("/elm.js")], []),
    ]),
    html.Body([], [
      html.h1_text([], "One Million Radio Buttons"),
      html.p([], [
        html.Text("Welcome! This is deeply inspired by "),
        html.a_text(
          [attr.href("https://onemillioncheckboxes.com/")],
          "One Million Checkboxes",
        ),
        html.Text(" by "),
        html.a_text([attr.href("https://eieio.games/")], "eieio.games"),
        html.Text(". He's a badass. Check him out."),
      ]),
      html.div([attr.id("omrb")], []),
      html.Script(
        [],
        "var app = Elm.Main.init({node: document.getElementById('omrb'), flags: "
          <> int.to_string(n_buttons)
          <> "});",
      ),
    ]),
  ])
  |> nakai.to_string
}

fn to_html_response(data: ResponseData) -> Response(ResponseData) {
  response.new(200)
  |> response.set_body(data)
  |> response.set_header("content-type", "text/html")
}
