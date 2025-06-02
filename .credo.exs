%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: [
        {Credo.Check.Refactor.Nesting, max_nesting: 3}
      ]
    }
  ]
}
