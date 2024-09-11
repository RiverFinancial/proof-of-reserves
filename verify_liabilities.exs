defmodule VerifyLiabilities do
  @moduledoc """
  Verify liabilities for a given Proof of Reserves file.
  You must pass set at least the following arguments:
  --email <email>
  --file <file>
  --account <account_uid>:<account_key>

  Multiple accounts can be provided by repeating the --account flag.
  """

  def run(args) do
    # leading newline to separate from terminal prompt
    IO.puts("\nRunning River Proof of Liabilities verifier...\n")

    with {_, {:ok, %{filename: filename, accounts: accounts}}} <- {:parse_args, parse_args(args)},
         {_, {:ok, block_height, tree}} <- {:verify_tree, verify_tree(filename)},
         {_, {:ok, balances}} <- {:verify_balances, verify_balances(accounts, block_height, tree)} do
      print_results(block_height, tree, balances)
    else
      {step, {:error, err}} ->
        IO.puts("error in #{step}: #{err}")
    end
  end

  # Parse command line arguments.
  # First, we read in the email, filename and accounts. Then, we parse the accounts to ensure they are in the correct format.
  defp parse_args(args) do
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
      _, acc ->
        acc
    end)
    |> case do
      %{account_strs: []} ->
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
      {:error, error} ->
        {:error, error}

      accounts when is_list(accounts) ->
        {:ok, %{email: email, filename: filename, accounts: accounts}}
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
        {:ok,
         %{
           account_id: account_id,
           account_uid: account_uid,
           account_subkey: subkey
         }}

      _ ->
        {:error,
         "invalid account format: #{account} does not match format <account_uid>:<account_key>"}
    end
  end

  @doc """
  Verify the tree is valid.
  We open the file and parse the liabilities.
  Then, we check if the tree is valid.
  """
  @spec verify_tree(String.t()) ::
          {:ok, non_neg_integer(), list(list(ProofOfReserves.MerkleSumTree.Node.t()))}
          | {:error, String.t()}
  def verify_tree(filename) do
    IO.puts("Verifying validity of Merkle Tree...")

    with {:ok, stream} <- open_file(filename) do
      {block_height, tree} = ProofOfReserves.Liabilities.parse_liabilities(stream)

      if ProofOfReserves.MerkleSumTree.verify_tree?(tree) do
        IO.puts("✅ Merkle Tree is valid! ✅")
        {:ok, block_height, tree}
      else
        {:error, "tree is invalid"}
      end
    else
      {:error, err} ->
        {:error, err}
    end
  end

  @doc """
  Verify the balances for the given accounts.
  We open the file and parse the liabilities.
  Then, for each account, we get the balance from the tree and return the results.
  """
  @spec verify_balances(
          %{
            accounts:
              list(%{
                account_uid: String.t(),
                account_subkey: binary()
              })
          },
          non_neg_integer(),
          list(list(ProofOfReserves.MerkleSumTree.Node.t()))
        ) ::
          {:ok,
           list(%{
             account_uid: String.t(),
             balance: integer()
           })}
          | {:error, String.t()}
  def verify_balances(accounts, block_height, tree) do
    account_uids =
      Map.new(accounts, fn %{account_id: id, account_uid: account_uid} -> {id, account_uid} end)

    IO.puts("Verifying balances in Merkle Tree...")

    balances =
      tree
      |> ProofOfReserves.MerkleSumTree.get_leaves()
      |> ProofOfReserves.find_balances_for_accounts(block_height, accounts)
      |> Enum.map(fn %{balance: balance, account_id: account_id} ->
        %{
          account_uid: Map.fetch!(account_uids, account_id),
          balance: balance
        }
      end)

    {:ok, balances}
  end

  # Open the file and return a stream.
  # If the file cannot be opened, return an error.
  @spec open_file(String.t()) :: {:ok, Stream.t()} | {:error, String.t()}
  defp open_file(filename) do
    try do
      {:ok, File.stream!(filename)}
    rescue
      e in File.Error -> {:error, "failed to open file #{filename}: #{e.reason}"}
    end
  end

  # Check if the system has UTF-8 support (for emojis)
  @spec utf8_support?() :: boolean()
  defp utf8_support?() do
    case System.get_env("LANG") || System.get_env("LC_CTYPE") do
      nil -> false
      locale -> String.contains?(locale, "UTF-8")
    end
  end

  @doc """
  Print the results to the console in a nice format.
  """
  @spec print_results(
          non_neg_integer(),
          list(list(ProofOfReserves.MerkleSumTree.Node.t())),
          list(%{
            account_uid: String.t(),
            balance: integer()
          })
        ) :: :ok
  def print_results(block_height, tree, account_balances) do
    use_emoji? = utf8_support?()

    {:ok, root} = ProofOfReserves.MerkleSumTree.get_tree_root(tree)
    IO.puts("=================================")
    IO.puts("River Proof of Liabilities Report")
    IO.puts("=================================")
    IO.puts("\n")
    IO.puts("=============SUMMARY================")
    IO.puts("Liabilities Root Hash: #{ProofOfReserves.Util.bin_to_hex!(root.hash)}")
    IO.puts("Total Liabilities: #{ProofOfReserves.Util.sats_to_btc(root.value)} BTC")
    IO.puts("Block Height: #{block_height}")
    IO.puts("Verified at: #{DateTime.utc_now()}")
    IO.puts("====================================")
    IO.puts("\n")
    IO.puts("============ACCOUNTS================")

    for %{account_uid: account_uid, balance: balance} <- account_balances do
      check =
        cond do
          not use_emoji? -> ""
          balance == 0 -> " ℹ️ "
          true -> " ✅"
        end

      balance =
        balance
        |> ProofOfReserves.Util.sats_to_btc()
        |> :erlang.float_to_binary(decimals: 8)
        |> String.pad_leading(12)

      IO.puts("  ----------------------------------")
      IO.puts("  | #{account_uid}: #{balance} BTC#{check} |")
      IO.puts("  ----------------------------------")
    end

    IO.puts("====================================")

    if Enum.any?(account_balances, fn %{balance: balance} -> balance == 0 end) do
      msg =
        "    Accounts with zero balance either had no balance as of this Proof or were not found in the tree.
      If you believe your balance was not zero as of this Proof, please double check the account ID and
      attestation key you provided."

      msg = if use_emoji?, do: "ℹ️" <> msg, else: msg

      IO.puts(msg)
    end
  end
end

VerifyLiabilities.run(System.argv())
