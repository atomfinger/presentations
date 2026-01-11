-module(demo).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/demo.gleam").
-export([main/0]).

-file("src/demo.gleam", 4).
-spec main() -> nil.
main() ->
    gleam_stdlib:println(<<"Hello from demo!"/utf8>>).
