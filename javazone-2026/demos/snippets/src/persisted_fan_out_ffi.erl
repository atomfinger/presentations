-module(persisted_fan_out_ffi).
-export([ensure_table/0, store_event/2, events_for/1]).

%% A minimal Mnesia-backed store: one `bag` table keyed by the fan-out
%% actor's own pid, so every published event for that actor accumulates
%% under one key and can be read back later. No schema file, no disc
%% storage - this runs entirely in memory, which is enough to show that
%% "persisted" doesn't have to mean "adopt a database service."
-record(published_event, {actor, event}).

ensure_table() ->
    mnesia:start(),
    case mnesia:create_table(published_event, [
        {attributes, record_info(fields, published_event)},
        {type, bag}
    ]) of
        {atomic, ok} -> nil;
        {aborted, {already_exists, published_event}} -> nil
    end.

store_event(Actor, Event) ->
    {atomic, ok} = mnesia:transaction(fun() ->
        mnesia:write(#published_event{actor = Actor, event = Event})
    end),
    nil.

events_for(Actor) ->
    {atomic, Records} = mnesia:transaction(fun() ->
        mnesia:read({published_event, Actor})
    end),
    [Event || #published_event{event = Event} <- Records].
