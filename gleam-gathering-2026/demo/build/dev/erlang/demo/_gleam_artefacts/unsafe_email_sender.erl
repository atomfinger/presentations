-module(unsafe_email_sender).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/unsafe_email_sender.gleam").
-export([send_welcome_email/1]).

-file("src/unsafe_email_sender.gleam", 17).
-spec is_valid_email(binary()) -> {ok, nil} | {error, binary()}.
is_valid_email(_) ->
    {ok, nil}.

-file("src/unsafe_email_sender.gleam", 21).
-spec is_user_registered(binary()) -> {ok, boolean()} | {error, binary()}.
is_user_registered(_) ->
    {ok, true}.

-file("src/unsafe_email_sender.gleam", 3).
-spec send_welcome_email(binary()) -> {ok, binary()} | {error, binary()}.
send_welcome_email(Email) ->
    gleam@result:'try'(
        is_valid_email(Email),
        fun(_) ->
            gleam@result:'try'(
                is_user_registered(Email),
                fun(Is_user_registered) -> case Is_user_registered of
                        true ->
                            {ok,
                                <<"Welcome email sent to "/utf8, Email/binary>>};

                        false ->
                            {error,
                                <<"User not registered in the system"/utf8>>}
                    end end
            )
        end
    ).
