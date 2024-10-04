import gleam/bytes_builder
import gleam/erlang/process.{type Selector, type Subject}
import gleam/function
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gleam/set.{type Set}
import logging.{Debug, Info}
import mist.{type ResponseData, type WebsocketMessage}
import nakai
import nakai/attr
import nakai/html

const n_buttons = 1_000_000

type ServerState {
  ServerState(selected_ix: Option(Int), active_conns: Set(Subject(Int)))
}

fn init_state() -> ServerState {
  ServerState(selected_ix: None, active_conns: set.new())
}

type Action {
  Select(Int)
  Value(reply_with: Subject(Option(Int)))
  Connect(Subject(Int))
  Disconnect(Subject(Int))
}

type ConnectionState {
  ConnectionState(
    global_subject: Subject(Action),
    connection_subject: Subject(Int),
  )
}

pub fn main() {
  // Configure logging
  logging.configure()
  logging.set_level(Debug)
  logging.log(logging.Info, "Start server")

  // Start the server loop
  let assert Ok(server_subject) = actor.start(init_state(), server_loop)

  // Compute the homepage once
  let homepage =
    make_page()
    |> bytes_builder.from_string
    |> mist.Bytes
    |> to_html_response

  // Start the webserver
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
            on_init: fn(_conn) { init_client_state(server_subject) },
            on_close: fn(state: ConnectionState) {
              process.send(server_subject, Disconnect(state.connection_subject))
            },
            handler: client_loop,
          )
        }

        _ -> homepage
      }
    }
    |> mist.new
    |> mist.port(8080)
    |> mist.start_http

  process.sleep_forever()
}

fn init_client_state(
  server_subject: Subject(Action),
) -> #(ConnectionState, Option(Selector(Int))) {
  let connection_subject: Subject(Int) = process.new_subject()
  process.send(server_subject, Connect(connection_subject))

  let connection_selector =
    process.new_selector()
    |> process.selecting(connection_subject, function.identity)

  #(
    ConnectionState(server_subject, connection_subject),
    Some(connection_selector),
  )
}

fn client_loop(
  ws_state: ConnectionState,
  conn: mist.WebsocketConnection,
  message: WebsocketMessage(Int),
) -> actor.Next(Int, ConnectionState) {
  case message {
    // We got a message from the frontend
    mist.Text(str) -> {
      case str |> int.parse |> result.then(is_valid_index) {
        Ok(num) -> {
          process.send(ws_state.global_subject, Select(num))
          actor.continue(ws_state)
        }

        // There's a parsing error, give up on this client
        Error(_) -> {
          actor.Stop(process.Normal)
        }
      }
    }

    // We got a message from the backend
    mist.Custom(selected_ix) -> {
      let assert Ok(_) =
        mist.send_text_frame(conn, selected_ix |> int.to_string)
      actor.continue(ws_state)
    }

    // Normal disconnection flow
    mist.Closed | mist.Shutdown -> {
      actor.Stop(process.Normal)
    }

    // We got something we didn't plan for, cut the connection
    _ -> {
      actor.Stop(process.Normal)
    }
  }
}

fn is_valid_index(box_ix: Int) -> Result(Int, Nil) {
  case 0 <= box_ix && box_ix < n_buttons {
    True -> Ok(box_ix)
    _ -> Error(Nil)
  }
}

fn server_loop(
  msg: Action,
  state: ServerState,
) -> actor.Next(Action, ServerState) {
  logging.log(
    Info,
    "Current connections: " <> set.size(state.active_conns) |> int.to_string,
  )
  case msg {
    // Someone clicked a button!
    Select(button_ix) -> {
      case button_ix |> is_valid_index {
        Ok(_) -> {
          let _ =
            state.active_conns
            |> set.map(fn(conn) { process.send(conn, button_ix) })

          actor.continue(ServerState(..state, selected_ix: Some(button_ix)))
        }

        Error(_) -> actor.continue(state)
      }
    }

    Value(client) -> {
      let ServerState(selected_ix, _) = state
      process.send(client, selected_ix)

      actor.continue(state)
    }

    Connect(new_connection) -> {
      ServerState(
        ..state,
        active_conns: state.active_conns |> set.insert(new_connection),
      )
      |> actor.continue
    }

    Disconnect(old_connection) -> {
      ServerState(
        ..state,
        active_conns: state.active_conns |> set.delete(old_connection),
      )
      |> actor.continue
    }
  }
}

fn make_page() -> String {
  html.Html([], [
    html.Head([
      html.title("One Million Radio Buttons"),
      html.meta([attr.name("viewport"), attr.content("width=device-width")]),
      html.Element("style", [], [
        html.Text(
          "input[type='radio'] { appearance: none; border: 1px solid grey; border-radius: 50%; width: 1.2em; height: 1.2em; } ",
        ),
        html.Text(
          "input[type='radio']:checked { background: rebeccapurple } ",
        ),
        html.Text(
          "input[type='radio']:hover { outline: 1px solid black } ",
        ),
      ]),
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

          document.addEventListener('scroll', (event) => {console.log('scrolling'); app.ports.onScroll.send('');});

          // TODO handle reconnection?
          var socket = new WebSocket('/ws');
          app.ports.sendMessage.subscribe(function(message) { socket.send(message);});
          socket.addEventListener('message', function(event) { app.ports.messageReceiver.send(event.data); });
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
