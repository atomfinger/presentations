import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/string

/// A live, redrawing table for our tiny worker fleet - the same idea as
/// `kubectl get pods` running under `watch`, just for three BEAM processes
/// instead of three containers.
pub type Status {
  Running
  Crashed
}

pub type WorkerState {
  WorkerState(status: Status, restarts: Int, last_request: String)
}

pub type Message {
  WorkerStarted(name: String)
  WorkerHandled(name: String, request_id: Int)
  WorkerCrashing(name: String, request_id: Int)
  Tick
}

type State {
  State(workers: Dict(String, WorkerState), self: Subject(Message), order: List(String))
}

const refresh_ms = 250

pub fn start(order: List(String)) -> actor.StartResult(Subject(Message)) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send_after(subject, refresh_ms, Tick)
    actor.initialised(State(workers: dict.new(), self: subject, order: order))
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    WorkerStarted(name) -> {
      let workers =
        dict.upsert(state.workers, name, fn(existing) {
          case existing {
            // Seen this name before, so this "start" is actually a restart
            // after a crash - bump the counter, same as kubectl's RESTARTS
            // column.
            Some(w) -> WorkerState(..w, restarts: w.restarts + 1)
            None -> WorkerState(status: Running, restarts: 0, last_request: "-")
          }
        })
      actor.continue(State(..state, workers: workers))
    }

    WorkerHandled(name, id) -> {
      let workers =
        dict.upsert(state.workers, name, fn(existing) {
          let text = "#" <> int.to_string(id) <> " ok"
          case existing {
            Some(w) -> WorkerState(..w, status: Running, last_request: text)
            None -> WorkerState(status: Running, restarts: 0, last_request: text)
          }
        })
      actor.continue(State(..state, workers: workers))
    }

    WorkerCrashing(name, id) -> {
      let workers =
        dict.upsert(state.workers, name, fn(existing) {
          let text = "#" <> int.to_string(id) <> " panic"
          case existing {
            Some(w) -> WorkerState(..w, status: Crashed, last_request: text)
            None -> WorkerState(status: Crashed, restarts: 0, last_request: text)
          }
        })
      actor.continue(State(..state, workers: workers))
    }

    Tick -> {
      render(state.workers, state.order)
      process.send_after(state.self, refresh_ms, Tick)
      actor.continue(state)
    }
  }
}

fn render(workers: Dict(String, WorkerState), order: List(String)) -> Nil {
  let clear_and_home = "\u{1b}[2J\u{1b}[H"
  let title = "Beam supervision demo - live worker fleet (Ctrl+C to stop)\n\n"
  let header =
    string.pad_end("NAME", to: 14, with: " ")
    <> string.pad_end("STATUS", to: 20, with: " ")
    <> string.pad_end("RESTARTS", to: 10, with: " ")
    <> "LAST REQUEST"

  let rows =
    order
    |> list.map(fn(name) { render_row(name, dict.get(workers, name)) })
    |> string.join("\n")

  io.print(clear_and_home <> title <> header <> "\n" <> rows <> "\n")
}

fn render_row(name: String, entry: Result(WorkerState, Nil)) -> String {
  case entry {
    Error(Nil) ->
      string.pad_end(name, to: 14, with: " ")
      <> string.pad_end("starting...", to: 20, with: " ")
      <> string.pad_end("0", to: 10, with: " ")
      <> "-"

    Ok(w) -> {
      let #(symbol, label, color) = case w.status {
        Running -> #("\u{2713}", "Running", "32")
        Crashed -> #("\u{2717}", "Crashed", "31")
      }
      let status_plain = symbol <> " " <> label
      let status_field =
        "\u{1b}[" <> color <> "m" <> string.pad_end(status_plain, to: 20, with: " ") <> "\u{1b}[0m"

      string.pad_end(name, to: 14, with: " ")
      <> status_field
      <> string.pad_end(int.to_string(w.restarts), to: 10, with: " ")
      <> w.last_request
    }
  }
}
