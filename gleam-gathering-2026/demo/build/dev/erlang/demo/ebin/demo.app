{application, demo, [
    {vsn, "1.0.0"},
    {applications, [gleam_stdlib,
                    gleeunit]},
    {description, ""},
    {modules, [demo,
               email_validator,
               safe_email_sender,
               unsafe_email_sender]},
    {registered, []}
]}.
