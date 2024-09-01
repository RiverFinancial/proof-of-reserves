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
  find_account_leaves finds all leaves that belong to a particular
  account using the attestation_key
  """
  def find_account_leaves(leaves, block_height, account_id, account_subkey) do
    attestation_key = Util.calculate_attestation_key(account_subkey, block_height, account_id)
    find_account_leaves(leaves, attestation_key)
  end

  def find_account_leaves(leaves, attestation_key) do
    leaves
    |> Enum.with_index()
    |> Enum.filter(fn {%{value: value, hash: hash}, idx} ->
      Util.leaf_hash(value, attestation_key, idx) == hash
    end)
    |> Enum.map(fn {node, _} -> node end)
  end

  @doc """
  get_account_balance calculates the balance of an account by summing the
  values of all leaves that belong to the account in a given tree.
  """
  @spec get_account_balance(
          list(list(MerkleSumTree.Node.t())),
          non_neg_integer(),
          non_neg_integer(),
          String.t()
        ) :: non_neg_integer()
  def get_account_balance(tree, block_height, account_id, account_subkey) do
    attestation_key = Util.calculate_attestation_key(account_subkey, block_height, account_id)
    get_account_balance(tree, attestation_key)
  end

  @doc """
  get_account_balance calculates the balance of an account by summing the
  values of all leaves that belong to the account in a given tree.
  """
  @spec get_account_balance(list(list(MerkleSumTree.Node.t())), String.t()) :: non_neg_integer()
  def get_account_balance(tree, attestation_key) do
    tree
    |> MerkleSumTree.get_leaves()
    |> find_account_leaves(attestation_key)
    |> Enum.reduce(0, fn node, acc -> acc + node.value end)
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
