-module(safe_email_sender).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/safe_email_sender.gleam").
-export([new/1, get_address/1, send_welcome_email/1]).
-export_type([valid_email/0]).

-opaque valid_email() :: {valid_email, binary()}.

-file("src/safe_email_sender.gleam", 8).
-spec new(binary()) -> {ok, valid_email()} | {error, binary()}.
new(Raw) ->
    case gleam_stdlib:contains_string(Raw, <<"@"/utf8>>) of
        true ->
            {ok, {valid_email, Raw}};

        _ ->
            {error, <<"Invalid email"/utf8>>}
    end.

-file("src/safe_email_sender.gleam", 15).
-spec get_address(valid_email()) -> binary().
get_address(Email) ->
    erlang:element(2, Email).

-file("src/safe_email_sender.gleam", 19).
-spec send_welcome_email(valid_email()) -> binary().
send_welcome_email(Email) ->
    <<"Welcome email sent to "/utf8, (erlang:element(2, Email))/binary>>.
