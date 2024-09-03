import gleam/bytes_builder
import gleam/erlang/process.{type Selector, type Subject}
import gleam/function
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string_builder
import logging.{Debug, Info}
import mist.{type Connection, type ResponseData, type WebsocketMessage}
import nakai
import nakai/attr
import nakai/html

const n_buttons = 10_000

type State {
  State(selected_ix: Option(Int), active_conns: List(Subject(Int)))
}

const init_state = State(selected_ix: None, active_conns: [])

type Action {
  Select(Int)
  Connect(Subject(Int))
  Value(reply_with: Subject(Option(Int)))
}

pub fn main() {
  let selected_subject: process.Subject(State) = process.new_subject()
  let assert Ok(global_actor) = actor.start(init_state, handle_message)

  let homepage =
    make_page()
    |> bytes_builder.from_string
    |> mist.Bytes
    |> to_html_response

  logging.configure()
  logging.set_level(Debug)
  logging.log(logging.Info, "Start server")
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
          logging.log(Info, "Got new WS connection")
          mist.websocket(
            request: request,
            on_init: fn(_conn) -> #(Subject(Action), Option(Selector(Int))) {
              let connection_subject: Subject(Int) = process.new_subject()
              process.send(global_actor, Connect(connection_subject))

              #(
                global_actor,
                process.new_selector()
                  // |> process.selecting(selected_subject, function.identity)
                  |> process.selecting(connection_subject, function.identity)
                  |> Some,
              )
            },
            on_close: fn(_state) {
              // TODO Remove connection from list
              Nil
            },
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

fn handle_ws_update(
  ws_state: Subject(Action),
  conn,
  message: WebsocketMessage(Int),
) -> actor.Next(Int, Subject(Action)) {
  io.debug(#("handle_ws_update", message))
  let global_actor = ws_state

  case message {
    mist.Text("ping") -> {
      let assert Ok(_) = mist.send_text_frame(conn, "pong")
      actor.continue(ws_state)
    }
    mist.Text(str) -> {
      case str |> int.parse |> result.then(is_valid_index) {
        Ok(num) -> {
          logging.log(Info, "handle_ws_update: " <> str)
          process.send(global_actor, Select(num))
          actor.continue(ws_state)
        }

        _ -> actor.continue(ws_state)
      }
    }
    mist.Custom(selected_ix) -> {
      logging.log(Info, "Got custom msg")

      let assert Ok(_) = mist.send_text_frame(conn, selected_ix |> int.to_string)
      actor.continue(ws_state)
    }
    mist.Closed | mist.Shutdown -> actor.Stop(process.Normal)
    _ -> actor.continue(ws_state)
  }
}

fn is_valid_index(box_ix: Int) -> Result(Int, Nil) {
  case 0 <= box_ix && box_ix < n_buttons {
    True -> Ok(box_ix)
    _ -> Error(Nil)
  }
}

fn handle_message(msg: Action, state: State) -> actor.Next(Action, State) {
  io.debug(#("handle_message: ", msg))

  case msg {
    Select(button_ix) -> {
      case 0 <= button_ix && button_ix < n_buttons {
        True -> {
          let State(_, connections) = state
          let _ =
            connections
            |> list.each(fn(conn) {
              logging.log(Debug, "Sending thing to process")
              process.send(conn, button_ix)
            })
          actor.continue(State(..state, selected_ix: Some(button_ix)))
        }
        _ -> actor.continue(state)
      }
    }

    Value(client) -> {
      let State(selected_ix, _) = state
      process.send(client, selected_ix)
      actor.continue(state)
    }

    Connect(connection) -> {
      actor.continue(
        State(..state, active_conns: [connection, ..{ state.active_conns }]),
      )
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
          <> "});

          // TODO handle reconnection
          var socket = new WebSocket('/ws');
          app.ports.sendMessage.subscribe(function(message) { socket.send(message);});
          socket.addEventListener('message', function(event) {console.log(event); app.ports.messageReceiver.send(event.data);});

          // TODO wire up port
          ",
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
