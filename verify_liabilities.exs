defmodule VerifyLiabilities do
  @moduledoc """
  Verify liabilities for a given Proof of Reserves file.
  """
  def run(args) do
    args
    |> parse_args()
    |> case do
      {:error, err} ->
        IO.puts("error parsing args: #{err}")

      {:ok, %{email: _email, filename: _filename, accounts: _accounts} = data} ->
        data
        |> verify_balances()
        |> case do
          {:error, err} ->
            IO.puts("error verifying balances: #{err}")

          {block_height, balances} when is_list(balances) ->
            print_results(block_height, balances)
        end
    end
  end

  # Parse command line arguments.
  # First, we read in the email, filename and accounts. Then, we parse the accounts to ensure they are in the correct format.
  defp parse_args(args) do
    # TODO

    args
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn
      # Only accept one email and one file
      ["--email", email], acc ->
        Map.put_new(acc, :email, email)
      ["--file", filename], acc ->
        Map.put_new(acc, :filename, filename)
      # accept multiple accounts, add to a list
      ["--account", account], acc ->
        Map.update(acc, :account_strs, [account], &[account | &1])
      # ignore other args
      _, acc -> acc
    end)
    |> case do
      %{account: []} ->
        {:error, "at least one account must be provided"}
      %{email: email} when is_nil(email) or length(email) == 0 ->
        {:error, "email is required"}
      %{filename: filename} when is_nil(filename) or length(filename) == 0 ->
        {:error, "filename is required"}

      %{email: email, filename: filename, account_strs: account_strs} = args
        when is_binary(email) and is_binary(filename) and is_list(account_strs) ->
          handle_args(args)
      _ ->
        {:error, "invalid arguments"}
    end
  end

  # Parse each individual account and return all args (email, filename, accounts)
  @spec handle_args(map()) :: {:ok, map()} | {:error, String.t()}
  defp handle_args(%{email: email, filename: filename, account_strs: account_strs}) do
    Enum.reduce_while(account_strs, [], fn acct_str, accounts ->
      case parse_account(email, acct_str) do
        {:ok, account} -> {:cont, [account | accounts]}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:error, error} -> {:error, error}
      accounts when is_list(accounts) -> {:ok, %{email: email, filename: filename, accounts: accounts}}
    end
  end

  # parse a single account string in the format <account_uid>:<account_key>
  @spec parse_account(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  defp parse_account(email, account) do
    case String.split(account, ":", parts: 2) do
      [account_uid, account_key] ->
        account_key = ProofOfReserves.Util.hex_to_bin!(account_key)
        account_id = ProofOfReserves.Util.base32_to_int!(account_uid)
        subkey = ProofOfReserves.Util.calculate_account_subkey(account_key, email, account_id)

        # Account ID and subkey are used to find account's leaves in the liabilities tree.
        # Account UID is used to print the account's balances in the final output.
        {:ok, %{
          account_id: account_id,
          account_uid: account_uid,
          account_subkey: subkey
        }}

      _ ->
        {:error, "invalid account format: #{account} does not match format <account_uid>:<account_key>"}
    end
  end

  @doc """
  Verify the balances for the given accounts.
  We open the file and parse the liabilities.
  Then, for each account, we get the balance from the tree and return the results.
  """
  @spec verify_balances(%{filename: String.t(), accounts: list(%{
    account_uid: String.t(),
    account_subkey: binary()
  })} | {:error, String.t()}) :: list(%{
    account_uid: String.t(),
    balance: integer()
  }) | {:error, String.t()}
  def verify_balances(%{filename: filename, accounts: accounts}) do
      filename
      |> open_file()
      # Handle the case where the file open fails
      |> case do
        {:ok, stream} ->
          {block_height, tree} =  ProofOfReserves.Liabilities.parse_liabilities(stream)

          # TODO: preferably do it one by one.
          balances =
            Enum.map(accounts, fn %{account_uid: account_uid,account_id: account_id, account_subkey: account_subkey} ->
              balance = ProofOfReserves.get_account_balance(tree, block_height, account_id, account_subkey)
              %{account_uid: account_uid, balance: balance}
            end)

          {block_height, balances}
        #
        {:error, err} ->
          {:error, err}
      end
  end

  defp open_file(filename) do
    try do
      {:ok, File.stream!(filename)}
    rescue
      e in File.Error -> {:error, "failed to open file #{filename}: #{e.reason}"}
    end
  end

  @doc """
  Print the results to the console in a nice format.
  """
  @spec print_results(non_neg_integer(), list(%{
    account_uid: String.t(),
    balance: integer()
  })) :: :ok
  def print_results(block_height,account_balances) do
    IO.puts("River Proof of Liabilities Report")
    IO.puts("================================")
    IO.puts("Block Height: #{block_height}")
    IO.puts("Verified at: #{DateTime.utc_now()}")
    IO.puts("Accounts:")
    # TODO: print in a nicer format
    for %{account_uid: account_uid, balance: balance} <- account_balances do
      IO.puts("  #{account_uid}: #{balance}")
    end
    IO.puts("================================")
  end
end

VerifyLiabilities.run(System.argv())
