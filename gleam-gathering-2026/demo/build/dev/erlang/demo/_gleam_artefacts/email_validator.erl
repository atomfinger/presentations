-module(email_validator).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/email_validator.gleam").
-export([new/1, get_address/1]).
-export_type([valid_email/0]).

-opaque valid_email() :: {valid_email, binary()}.

-file("src/email_validator.gleam", 8).
-spec new(binary()) -> {ok, valid_email()} | {error, binary()}.
new(Raw) ->
    case gleam_stdlib:contains_string(Raw, <<"@"/utf8>>) of
        true ->
            {ok, {valid_email, Raw}};

        _ ->
            {error, <<"Invalid email"/utf8>>}
    end.

-file("src/email_validator.gleam", 15).
-spec get_address(valid_email()) -> binary().
get_address(Email) ->
    erlang:element(2, Email).
