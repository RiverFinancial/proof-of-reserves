defmodule ProofOfReserves do
  @moduledoc """
  Documentation for `ProofOfReserves`.
  """

  alias ProofOfReserves.{Liabilities, Liability, MerkleSumTree, Util}

  # BUILDING THE MERKLE SUM TREE

  @doc """
  build_liabilities_tree builds a Merkle Sum Tree from a list of liabilities.
  First, we split the liabilities to mask account balances and ensure the
  liability count is a power of 2, then we shuffle them.
  Then, we convert the liabilities to nodes and build the Merkle Sum Tree.
  """
  @spec build_liabilities_tree(non_neg_integer(), list(Liability.t()), non_neg_integer()) ::
          list(list(MerkleSumTree.Node.t()))
  def build_liabilities_tree(block_height, liabilities, liability_maximum_threshold_sat) do
    liabilities
    # split the liabilities to mask account balances and ensure the liability count is a power of 2
    |> split_liabilities(liability_maximum_threshold_sat)
    # shuffle the liabilities to mask account balances
    |> shuffle_liabilities()
    |> Enum.with_index()
    # convert the liabilities to leaves
    |> Enum.map(fn {liability, idx} ->
      Liabilities.liability_to_node(block_height, idx, liability)
    end)
    # build the Merkle Sum Tree
    |> MerkleSumTree.build_merkle_tree()
  end

  @doc """
  split_liabilities divides the liabilities according to the following rules:
  1. split all liabilities at least once (unless the liability is 1 sat).
  2. All leaves must be below the threshold.
  3. Divide the liabilities until a power of two is reached. If this is impossible,
     we add zero-amount liabilities to reach the next power of two.
  """
  @spec split_liabilities(list(Liability.t()), non_neg_integer()) :: list(Liability.t())
  def split_liabilities(liabilities, liability_maximum_threshold_sat) do
    liabilities =
      liabilities
      |> Enum.flat_map(fn liability ->
        # 1. split all liabilities at least once
        case Liabilities.split_liability(liability) do
          [a, b] ->
            # 2. All leaves must be below the threshold.
            Liabilities.split_liability_below_threshold(a, liability_maximum_threshold_sat) ++
              Liabilities.split_liability_below_threshold(b, liability_maximum_threshold_sat)

          # if the liability is 1 sat, we can't split it
          [a] ->
            [a]
        end
      end)

    # 3. Divide the liabilities until a power of two is reached.
    Liabilities.split_liabilities_to_power_of_two(liabilities)
  end

  @doc """
  shuffle_liabilities shuffles the liabilities using cryptographic randomness.
  It does this by zipping each liability with a random number, sorting by the random number,
  then extracting the liability.
  """
  @spec shuffle_liabilities(list(Liability.t())) :: list(Liability.t())
  def shuffle_liabilities(liabilities) do
    liabilities
    |> Enum.map(fn liability -> {Util.crypto_rand_int(), liability} end)
    |> Enum.sort(fn {rand1, _}, {rand2, _} -> rand1 < rand2 end)
    |> Enum.map(fn {_rand, liability} -> liability end)
  end

  # ACCOUNT BALANCE CALCULATIONS

  @doc """
  find_balances_for_accounts is the async version of find_balances_for_accounts.
  It is a recursive function that splits the leaves into two lists, finds the balances
  for each account in each list, and then merges the results of the two lists.
  """
  @spec find_balances_for_accounts(
          list(MerkleSumTree.Node.t()),
          non_neg_integer(),
          list(%{
            account_id: non_neg_integer(),
            account_subkey: binary()
          })
        ) ::
          list(%{
            account_id: non_neg_integer(),
            balance: non_neg_integer(),
            attestation_key: binary()
          })
  def find_balances_for_accounts(leaves, block_height, accounts) do
    account_balances =
      Enum.map(accounts, fn %{account_id: account_id, account_subkey: subkey} ->
        %{
          account_id: account_id,
          balance: 0,
          attestation_key: Util.calculate_attestation_key(subkey, block_height, account_id)
        }
      end)

    do_find_balances_for_accounts(leaves, 0, account_balances)
  end

  # helper function for find_balances_for_accounts
  @spec do_find_balances_for_accounts(
          list(MerkleSumTree.Node.t()),
          non_neg_integer(),
          list(%{
            account_id: non_neg_integer(),
            balance: non_neg_integer(),
            attestation_key: binary()
          })
        ) ::
          list(%{
            account_id: non_neg_integer(),
            balance: non_neg_integer(),
            attestation_key: binary()
          })
  defp do_find_balances_for_accounts([], _leaf_idx, account_balances), do: account_balances

  defp do_find_balances_for_accounts([leaf], leaf_idx, account_balances) do
    # when there is only one leaf, we can simply check if the leaf hash matches the leaf hash
    # for each account in the list. If it does, we add the value to the balance.
    Enum.map(account_balances, fn %{balance: balance, attestation_key: attestation_key} =
                                    account_balance ->
      # TODO: only a single account should match the leaf hash at most, so we can return early
      if Util.leaf_hash(leaf.value, attestation_key, leaf_idx) == leaf.hash do
        # if the leaf hash matches, we add the value to the balance
        Map.put(account_balance, :balance, balance + leaf.value)
      else
        account_balance
      end
    end)
  end

  defp do_find_balances_for_accounts(leaves, leaf_idx, account_balances) do
    # Split the leaves into two lists
    leaf_ct = length(leaves)
    mid_idx = div(leaf_ct, 2)

    {left_leaves, right_leaves} = Enum.split(leaves, mid_idx)

    # Recursively & asynchronously find the balances for each account in both lists
    left_task =
      Task.async(fn -> do_find_balances_for_accounts(left_leaves, leaf_idx, account_balances) end)

    right_task =
      Task.async(fn ->
        do_find_balances_for_accounts(right_leaves, leaf_idx + mid_idx, account_balances)
      end)

    left_balances = Task.await(left_task, :infinity)
    right_balances = Task.await(right_task, :infinity)

    # Merge the results of the two lists
    Enum.zip_with(left_balances, right_balances, fn
      # the matching on account_id and attestation_key ensures that the balances are added to the correct account
      %{account_id: account_id, balance: left_balance, attestation_key: attestation_key},
      %{account_id: account_id, balance: right_balance, attestation_key: attestation_key} ->
        %{
          account_id: account_id,
          balance: left_balance + right_balance,
          attestation_key: attestation_key
        }
    end)
  end

  @doc """
  get_tree_root returns the root node of a Merkle Sum Tree.
  """
  @spec get_tree_root(list(list(MerkleSumTree.Node.t()))) :: {:ok, MerkleSumTree.Node.t()}
  def get_tree_root(tree), do: MerkleSumTree.get_tree_root(tree)

  # FILE OPERATIONS

  @doc """
  serialize_liabilities formats the Proof of Liabilities into a String.
  """
  @spec serialize_liabilities(non_neg_integer(), list(list(MerkleSumTree.Node.t()))) :: String.t()
  def serialize_liabilities(block_height, tree),
    do: Liabilities.serialize_liabilities(block_height, tree)
end
