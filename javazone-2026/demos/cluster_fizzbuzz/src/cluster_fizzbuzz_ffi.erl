-module(cluster_fizzbuzz_ffi).
-export([global_register/2, global_whereis/1, raw_send/2, raw_receive/1, node_name/0, plain_arguments/0, pid_node/1, connect/1]).

%% Register a pid under a name that every connected node can look up,
%% using Erlang's built-in `global` module - the cluster-wide sibling of
%% the node-local `erlang:register/2`.
global_register(Name, Pid) ->
    yes = global:register_name(Name, Pid),
    nil.

global_whereis(Name) ->
    case global:whereis_name(Name) of
        undefined -> {error, nil};
        Pid -> {ok, Pid}
    end.

%% A plain, untyped `!` send - the same raw primitive every BEAM language
%% is built on top of, used here so a message can be addressed straight to
%% a pid discovered via `global`, no locally-registered name required.
raw_send(Pid, Msg) ->
    Pid ! Msg,
    nil.

raw_receive(Timeout) ->
    receive
        Msg -> {ok, Msg}
    after Timeout ->
        {error, nil}
    end.

node_name() ->
    atom_to_binary(node(), utf8).

%% Everything passed after `-extra` on the erl command line, so a plain
%% `erl ... -extra central` or `erl ... -extra query node2` can tell one
%% compiled build which role to play.
plain_arguments() ->
    [unicode:characters_to_binary(Arg) || Arg <- init:get_plain_arguments()].

%% Which node a pid lives on - used purely for the demo's own logging, so
%% we can print "node2@host asked about 15" instead of an opaque pid.
pid_node(Pid) ->
    atom_to_binary(node(Pid), utf8).

%% Distributed Erlang connects nodes lazily, on first contact. `global`'s
%% name table only syncs across nodes that are already connected, so a
%% querying node needs to explicitly reach out to the central node once
%% before `global:whereis_name` can find anything registered there.
connect(NodeName) ->
    Node = binary_to_atom(NodeName, utf8),
    net_kernel:connect_node(Node),
    nil.
