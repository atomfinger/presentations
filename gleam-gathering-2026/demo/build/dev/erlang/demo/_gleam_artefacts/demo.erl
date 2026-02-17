-module(demo).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/demo.gleam").
-export([main/0]).

-file("src/demo.gleam", 4).
-spec main() -> {ok, nil} | {error, binary()}.
main() ->
    gleam@result:'try'(
        safe_email_sender:new(<<"wibbly@wobbly.wabbely"/utf8>>),
        fun(Good_email_result) ->
            _ = safe_email_sender:send_welcome_email(Good_email_result),
            gleam@result:'try'(
                safe_email_sender:new(<<"wibbly"/utf8>>),
                fun(Bad_email_result) ->
                    _ = safe_email_sender:send_welcome_email(Bad_email_result),
                    {ok, nil}
                end
            )
        end
    ).
