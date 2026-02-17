-module(naive_email_sender).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/naive_email_sender.gleam").
-export([send_welcome_email/1]).

-file("src/naive_email_sender.gleam", 3).
-spec send_welcome_email(binary()) -> {ok, binary()} | {error, binary()}.
send_welcome_email(Email) ->
    {ok, <<"Welcome email sent to "/utf8, Email/binary>>}.
