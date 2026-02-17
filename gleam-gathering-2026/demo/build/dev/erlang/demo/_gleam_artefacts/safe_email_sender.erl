-module(safe_email_sender).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/safe_email_sender.gleam").
-export([send_welcome_email/1, new/1]).
-export_type([valid_email/0]).

-opaque valid_email() :: {valid_email, binary()}.

-file("src/safe_email_sender.gleam", 17).
-spec send_welcome_email(valid_email()) -> {ok, binary()} | {error, binary()}.
send_welcome_email(Email) ->
    {ok, <<"Welcome email sent to "/utf8, (erlang:element(2, Email))/binary>>}.

-file("src/safe_email_sender.gleam", 22).
-spec is_valid_email(binary()) -> {ok, nil} | {error, binary()}.
is_valid_email(_) ->
    {ok, nil}.

-file("src/safe_email_sender.gleam", 26).
-spec is_user_registered(binary()) -> {ok, boolean()} | {error, binary()}.
is_user_registered(_) ->
    {ok, true}.

-file("src/safe_email_sender.gleam", 7).
-spec new(binary()) -> {ok, valid_email()} | {error, binary()}.
new(Address) ->
    gleam@result:'try'(
        is_valid_email(Address),
        fun(_) ->
            gleam@result:'try'(
                is_user_registered(Address),
                fun(Is_user_registered) -> case Is_user_registered of
                        true ->
                            {ok, {valid_email, Address}};

                        false ->
                            {error,
                                <<"User not registered in the system"/utf8>>}
                    end end
            )
        end
    ).
