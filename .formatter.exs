[
  # Format these file patterns
  inputs: [
    "*.{ex,exs}",
    "priv/*/seeds.exs",
    "{config,lib,test}/**/*.{ex,exs}"
  ],

  # Exclude certain patterns
  subdirectories: ["priv/*/migrations"],

  # Line length limit
  line_length: 98,

  # Force certain files to use certain formatters
  locals_without_parens: [
    # Add any function names that should not have parens
    field: :*,
    schema: :*,
    pipe_through: :*,
    plug: :*,
    socket: :*,
    belongs_to: :*,
    has_many: :*,
    has_one: :*,
    many_to_many: :*
  ],

  # Export formatter configuration
  export: [
    locals_without_parens: [
      field: 2,
      field: 3,
      belongs_to: 2,
      belongs_to: 3,
      has_many: 2,
      has_many: 3,
      has_one: 2,
      has_one: 3,
      many_to_many: 2,
      many_to_many: 3
    ]
  ]
]
