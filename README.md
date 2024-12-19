<h1 align="center">
    BrowserForge.ex
</h1>

<h4 align="center">
    🎭 Intelligent browser header & fingerprint generator for Elixir
</h4>

---

## What is it?

BrowserForge.ex is an Elixir implementation of browser header and fingerprint generation that mimics the frequency of different browsers, operating systems, and devices found in the wild.

## Features

- Uses a Bayesian generative network to mimic actual web traffic
- Fast runtime performance
- Simple API design
- Extensive customization options
- Type safety with typespecs

## Installation

Add to your mix.exs:
```elixir
def deps do
  [
    {:browserforge, "~> 0.1.0"}
  ]
end
```

## Usage

### Generating Headers

```elixir
generator = BrowserForge.Headers.Generator.new
headers = BrowserForge.Headers.Generator.generate(generator)
```

## Documentation

Full documentation can be found at [https://hexdocs.pm/browserforge](https://hexdocs.pm/browserforge)

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

---
