import gleam/erlang/process.{type Name}
import gleam/otp/static_supervisor as supervisor
import gleam/otp/supervision
import supervision_demo/dashboard
import supervision_demo/worker.{type Message}

@external(erlang, "rand", "uniform")
fn rand_uniform(n: Int) -> Int

const worker_order = ["worker-a", "worker-b", "worker-c"]

pub fn main() -> Nil {
  let assert Ok(dashboard_started) = dashboard.start(worker_order)
  let dashboard_subject = dashboard_started.data

  let worker_a = process.new_name("worker_a")
  let worker_b = process.new_name("worker_b")
  let worker_c = process.new_name("worker_c")

  // `restart_tolerance` is cranked way up on purpose: this demo is about
  // showing that individual crashes get quietly handled, not about hitting
  // the supervisor's own "too many crashes, I give up" escalation.
  let assert Ok(_started) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.restart_tolerance(intensity: 1_000_000, period: 1)
    |> supervisor.add(
      supervision.worker(fn() {
        worker.start(worker_a, "worker-a", dashboard_subject)
      }),
    )
    |> supervisor.add(
      supervision.worker(fn() {
        worker.start(worker_b, "worker-b", dashboard_subject)
      }),
    )
    |> supervisor.add(
      supervision.worker(fn() {
        worker.start(worker_c, "worker-c", dashboard_subject)
      }),
    )
    |> supervisor.start

  simulate_traffic(worker_a, worker_b, worker_c, 1)
}

fn simulate_traffic(
  worker_a: Name(Message),
  worker_b: Name(Message),
  worker_c: Name(Message),
  request_id: Int,
) -> Nil {
  let target = case rand_uniform(3) {
    1 -> worker_a
    2 -> worker_b
    _ -> worker_c
  }

  send_request(target, request_id)

  process.sleep(500)
  simulate_traffic(worker_a, worker_b, worker_c, request_id + 1)
}

/// Send a request to a named worker, but check the name is actually
/// registered first. Right after a crash there is a brief window before the
/// supervisor has finished restarting the worker where the name isn't
/// registered to anyone yet - sending straight into that gap would crash the
/// traffic simulator itself. This is an honest, small edge of "let it
/// crash": the restart is fast, not instant.
fn send_request(name: Name(Message), id: Int) -> Nil {
  case process.named(name) {
    Ok(_pid) -> process.send(process.named_subject(name), worker.HandleRequest(id))
    Error(Nil) -> Nil
  }
}
