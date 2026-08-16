import gleam/erlang/process.{type Name, type Subject}
import gleam/otp/actor
import supervision_demo/dashboard.{type Message as DashboardMessage}

/// The only message our workers understand: "please handle this request".
pub type Message {
  HandleRequest(id: Int)
}

type State {
  State(label: String, dashboard: Subject(DashboardMessage))
}

/// Erlang's own random number generator, reached via FFI. Gleam doesn't
/// ship randomness in its core standard library on purpose - it's not a
/// pure function - so we borrow the one that's always been sitting in the
/// runtime underneath us.
@external(erlang, "rand", "uniform")
fn rand_uniform(n: Int) -> Int

/// Start a worker, registered under `name` so that it can be found again
/// under the exact same name even after the supervisor restarts it with a
/// brand new pid. This function is what the supervisor calls both for the
/// very first start *and* every restart afterwards, which is exactly why
/// it's the right place to tell the dashboard "I'm up".
pub fn start(
  name: Name(Message),
  label: String,
  dashboard: Subject(DashboardMessage),
) -> actor.StartResult(Subject(Message)) {
  process.send(dashboard, dashboard.WorkerStarted(label))

  actor.new(State(label:, dashboard:))
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    HandleRequest(id) -> {
      // Roughly 1 in 6 requests is "bad" and blows the worker up. This is
      // the entire simulated failure mode for the whole demo.
      case rand_uniform(6) {
        1 -> {
          process.send(state.dashboard, dashboard.WorkerCrashing(state.label, id))
          panic as "simulated failure while handling a request"
        }
        _ -> {
          process.send(state.dashboard, dashboard.WorkerHandled(state.label, id))
          actor.continue(state)
        }
      }
    }
  }
}
