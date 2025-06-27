[
  import_deps: [:phoenix],
  plugins:
    if(Code.ensure_loaded?(Phoenix.LiveView.HTMLFormatter),
      do: [Phoenix.LiveView.HTMLFormatter],
      else: []
    ),
  subdirectories: ["priv/*/migrations"],
  locals_without_parens: [from: 2],
  inputs: [
    "mix.exs",
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs"
  ],
  line_length: 80
]
