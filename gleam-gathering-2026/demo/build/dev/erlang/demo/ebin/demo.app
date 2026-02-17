{application, demo, [
    {vsn, "1.0.0"},
    {applications, [gleam_stdlib,
                    gleeunit]},
    {description, ""},
    {modules, [demo,
               email,
               naive_email_sender,
               safe_email_sender,
               unsafe_email_sender]},
    {registered, []}
]}.
