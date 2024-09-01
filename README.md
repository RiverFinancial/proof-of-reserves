# ProofOfReserves

River's Proof of Reserves implementation in Elixir. This implementation is based on BitMEX's Proof of Reseres Python implementation, found [here](https://github.com/BitMEX/proof-of-reserves-liabilities).

This library is used by River to generate its Proof of Liabilities tree and to allow users to download and verify the Proof of Liabilities. 

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `proof_of_reserves` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:proof_of_reserves, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/proof_of_reserves>.

