-module(unsafe_email_sender).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/unsafe_email_sender.gleam").
-export([send_welcome_email/1]).

-file("src/unsafe_email_sender.gleam", 1).
-spec send_welcome_email(binary()) -> binary().
send_welcome_email(Email) ->
    <<"Welcome email sent to "/utf8, Email/binary>>.
