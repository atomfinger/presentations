-module(email).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/email.gleam").
-export([parse_email/1, verify_email/1, register_email/1, onboard_user/1]).
-export_type([valid_email/0, verified_email/0, registered_user_email/0]).

-opaque valid_email() :: {valid_email, binary()}.

-opaque verified_email() :: {verified_email, valid_email()}.

-opaque registered_user_email() :: {registered_user_email, verified_email()}.

-file("src/email.gleam", 45).
-spec is_valid_email(binary()) -> boolean().
is_valid_email(Input) ->
    erlang:error(#{gleam_error => todo,
            message => <<"`todo` expression evaluated. This code has not yet been implemented."/utf8>>,
            file => <<?FILEPATH/utf8>>,
            module => <<"email"/utf8>>,
            function => <<"is_valid_email"/utf8>>,
            line => 46}).

-file("src/email.gleam", 15).
-spec parse_email(binary()) -> {ok, valid_email()} | {error, binary()}.
parse_email(Input) ->
    case is_valid_email(Input) of
        true ->
            {ok, {valid_email, Input}};

        false ->
            {error, <<"Invalid email format"/utf8>>}
    end.

-file("src/email.gleam", 49).
-spec verification_link_clicked(valid_email()) -> boolean().
verification_link_clicked(Input) ->
    erlang:error(#{gleam_error => todo,
            message => <<"`todo` expression evaluated. This code has not yet been implemented."/utf8>>,
            file => <<?FILEPATH/utf8>>,
            module => <<"email"/utf8>>,
            function => <<"verification_link_clicked"/utf8>>,
            line => 50}).

-file("src/email.gleam", 22).
-spec verify_email(valid_email()) -> {ok, verified_email()} | {error, binary()}.
verify_email(Email) ->
    case verification_link_clicked(Email) of
        true ->
            {ok, {verified_email, Email}};

        false ->
            {error, <<"Email not verified"/utf8>>}
    end.

-file("src/email.gleam", 53).
-spec email_already_registered(verified_email()) -> boolean().
email_already_registered(Input) ->
    erlang:error(#{gleam_error => todo,
            message => <<"`todo` expression evaluated. This code has not yet been implemented."/utf8>>,
            file => <<?FILEPATH/utf8>>,
            module => <<"email"/utf8>>,
            function => <<"email_already_registered"/utf8>>,
            line => 54}).

-file("src/email.gleam", 29).
-spec register_email(verified_email()) -> {ok, registered_user_email()} |
    {error, binary()}.
register_email(Email) ->
    case email_already_registered(Email) of
        false ->
            {ok, {registered_user_email, Email}};

        true ->
            {error, <<"Email already registered"/utf8>>}
    end.

-file("src/email.gleam", 38).
-spec onboard_user(binary()) -> {ok, registered_user_email()} |
    {error, binary()}.
onboard_user(Raw_email) ->
    _pipe = Raw_email,
    _pipe@1 = parse_email(_pipe),
    _pipe@2 = gleam@result:'try'(_pipe@1, fun verify_email/1),
    gleam@result:'try'(_pipe@2, fun register_email/1).
