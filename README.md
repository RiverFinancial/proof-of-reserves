# Proof Of Reserves

River's Proof of Reserves implementation in Elixir. This implementation is based on BitMEX's Proof of Reserves Python implementation, found [here](https://github.com/BitMEX/proof-of-reserves-liabilities).

This library is used by River to generate its Proof of Liabilities tree and to allow users to download and verify the Proof of Liabilities. 

See River's [Proof of Reserves page](https://river.com/reserves) for more information.

## Verifying River's Proof of Reserves 

This library comes with a `verify_liabilities.exs` script that will verify River's Proof of Reserves and the balances of any accounts you provide. The following steps will walk you through the process of verifying River's Proof of Reserves.

### 1. Fetch the Proof of Reserves Data

Go to River's [Proof of Reserves](https://river.com/reserves) page. Log in with the email address you used to sign up for River. 

Click "Verify Liabilities" and select the "Verify on your computer" option. This will allow you to download the Proof of Liabilities CSV file. Note the path to this CSV file, as you will need to provide it to the command in the next step. 

Click "Continue" and you will be prompted to run the setup script also seen in the next step.

### 2. Setup the Project

In your terminal, run this command to clone the repository and install the dependencies. This step will install [asdf](https://asdf-vm.com/) and the Erlang/Elixir SDK. 

If you already have Erlang and Elixir installed or have already verified River's Proof of Reserves before, you can skip this step. If you have asdf installed but not Erlang/Elixir, you can install the SDK with asdf by running `asdf install` from this directory and skip this step.

```bash
git clone https://github.com/RiverFinancial/proof-of-reserves.git
cd proof-of-reserves
./scripts/setup.sh
source $HOME/.asdf/asdf.sh
```

This script will install Erlang/Elixir and the project dependencies. It will then compile the library. 

Back in River's Proof of Reserves flow, click "Continue" and you will see the verification command, also shown in the step below. 

### 2. Run the Verification Script

You will need to replace a few variables in the command below to run the script successfully. These values can be found in the River Proof of Reserves flow. If you followed the steps above, you will now see the command in the final screen. The command on the River page will already have your email and account string(s) filled in. You will need to fill in the `<CSV_PATH>` with the path to the CSV file you downloaded in Step 1. 

- `<EMAIL>` with the email address you used to sign up for River.
- `<ACCOUNT_STRING>` in the format `<ACCOUNT_ID>:<ACCOUNT_KEY>`. If you have multiple accounts, you can provide this flag multiple times, like so: `--account <ACCOUNT_STRING_1> --account <ACCOUNT_STRING_2>`. You can find your account ID and key in the Proof of Reserves flow.
- `<CSV_PATH>` with the path to the CSV file you downloaded in Step 1. The downloaded file will initially be zipped, so you will need to unzip it before providing the path to the CSV file. 

```bash
mix run verify_liabilities.exs --email <EMAIL> --account <ACCOUNT_STRING> --file <CSV_PATH>
```

If the verification is successful, it will output your balance and a summary of the verification. 

If you click continue on the River page, you can check that these balances are correct. 

## Installation as a Library

This section is for developers who want to use this library in their own projects.

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

## Code format on commit

To avoid situations where you forget to run format_all or your IDE doesn't format on save. You can utilize a pre-commit hook to always format your staged files as they're being committed. This hook will only format files you're about to commit, so it avoids looking over the entire codebase and is typically faster than format_all. To enable it, simply run:

```
git config --add core.hookspath scripts/hooks
```

## Security

If you find a vulnerability, please responsibly disclose by sending an email to `security@river.com`.
