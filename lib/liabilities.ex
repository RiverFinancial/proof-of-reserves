defmodule ProofOfReserves.Liabilities do
  @moduledoc """
  Liabilities is a module that is used to calculate a Proof of Liabilities.
  """

  alias ProofOfReserves.{Liability, MerkleSumTree, Util}

  @liability_minimum_threshold_sat 1

  @doc """
  dummy_liability returns a dummy liability
  """
  @spec dummy_liability() :: Liability.t()
  def dummy_liability() do
    Liability.new(
      0,
      Util.hex_to_bin!("0000000000000000000000000000000000000000000000000000000000000000"),
      0
    )
  end

  # FOR TESTING ONLY
  def fake_liability_account_subkey(),
    do: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"

  def fake_liability(amount) do
    %Liability{
      account_id: 1,
      account_subkey: Util.hex_to_bin!(fake_liability_account_subkey()),
      amount: amount
    }
  end

  @doc """
  serialize_liabilities serializes the liabilities into a string
  """
  @spec serialize_liabilities(non_neg_integer, list(list(MerkleSumTree.Node.t()))) :: String.t()
  def serialize_liabilities(block_height, tree) do
    "block_height:#{block_height}\n" <> MerkleSumTree.serialize_tree(tree)
  end

  @doc """
  parse_liabilities parses the liabilities from a stream
  """
  # @spec parse_liabilities(Stream.t()) :: {non_neg_integer, list(MerkleSumTree.Node.t())}
  def parse_liabilities(stream) do
    ["block_height:" <> block_height_str] = Enum.take(stream, 1)

    block_height =
      block_height_str
      |> String.trim()
      |> String.to_integer()

    tree = MerkleSumTree.parse_tree(Enum.drop(stream, 1))

    {block_height, tree}
  end

  @doc """
  split_liability divides a liability into 2 liabilities whose amounts sum
  to the amount of the original liability.
  This function should never be called with amount <= 1 sat
  """
  @spec split_liability(Liability.t()) :: list(Liability.t())
  def split_liability(liability) do
    if liability.amount <= @liability_minimum_threshold_sat do
      [liability]
    else
      # the rand.uniform(n) returns a random number 1 <= x <= n
      # so the -1 ensures that we never end up with a zero-amount liability.
      random_split = :rand.uniform(liability.amount - 1)
      a = Liability.new(liability.account_id, liability.account_subkey, random_split)

      b =
        Liability.new(
          liability.account_id,
          liability.account_subkey,
          liability.amount - random_split
        )

      # divide the liability into two liabilities
      [a, b]
    end
  end

  @spec split_liability_below_threshold(Liability.t(), non_neg_integer()) :: list(Liability.t())
  def split_liability_below_threshold(liability, threshold) do
    if liability.amount <= threshold do
      [liability]
    else
      Enum.flat_map([liability], fn liability ->
        # split the liability into two liabilities
        [a, b] = split_liability(liability)
        # recursively split the liabilities until they are all below the threshold
        split_liability_below_threshold(a, threshold) ++
          split_liability_below_threshold(b, threshold)
      end)
    end
  end

  @doc """
  split_liabilities_to_power_of_two divides the liabilities until a power of two is reached.
  note: This logic attempts to use splitting to get to a power of two.
  but if we can't get there, we add zero-amount liabilities. It may be
  simpler to just add zero-amount liabilities until we reach the next power of two.
  """
  @spec split_liabilities_to_power_of_two(list(Liability.t())) :: list(Liability.t())
  def split_liabilities_to_power_of_two(liabilities) do
    new_splits =
      liabilities
      |> length()
      |> diff_to_next_power_of_two()

    liabilities = split_liabilities_to_add_n(liabilities, new_splits)

    # if we are still not at the target length, we add zero-amount liabilities
    # with dummy account_subkeys to reach the target length.
    new_dummy_ct =
      liabilities
      |> length()
      |> diff_to_next_power_of_two()

    add_n_dummy_liabilities(liabilities, new_dummy_ct)
  end

  # note: this function will crash if new_splits > len(liabilities)
  @spec split_liabilities_to_add_n(list(Liability.t()), non_neg_integer()) :: list(Liability.t())
  defp split_liabilities_to_add_n(liabilities, 0), do: liabilities

  defp split_liabilities_to_add_n(liabilities, new_splits) do
    # split the list into 2 at index N, where the first list will be split into 2 each,
    # this will add N new liabilities.
    {to_split, rest} = Enum.split(liabilities, new_splits)

    splitd = Enum.flat_map(to_split, &split_liability/1)

    # check if any splits failed/skipped. We'll have to try to split again
    new_splits = new_splits * 2 - length(splitd)
    # but we'll do so on different liabilities since some are 1-sat liabilities.
    # This is recursive so we will gradually work our way through the
    # list looking for non-1-sat liabilites to split
    rest =
      split_liabilities_to_add_n(
        rest,
        # ensure new_splits is not > len(rest)
        min(length(rest), new_splits)
      )

    splitd ++ rest
  end

  # adds N dummy liabilities to the list
  @spec add_n_dummy_liabilities(list(Liability.t()), non_neg_integer()) :: list(Liability.t())
  defp add_n_dummy_liabilities(liabilities, 0), do: liabilities

  defp add_n_dummy_liabilities(liabilities, n) do
    Enum.concat(liabilities, Enum.map(1..n, fn _ -> dummy_liability() end))
  end

  # calculates the difference to the next power of two
  @spec diff_to_next_power_of_two(non_neg_integer()) :: non_neg_integer()
  defp diff_to_next_power_of_two(n) do
    Util.next_power_of_two(n) - n
  end

  @doc """
  liability_to_node converts a liability to a node in the Merkle Sum Tree.
  """
  @spec liability_to_node(non_neg_integer(), non_neg_integer(), Liability.t()) ::
          MerkleSumTree.Node.t()
  def liability_to_node(block_height, leaf_idx, %Liability{
        account_id: account_id,
        amount: amount,
        account_subkey: account_subkey
      }) do
    attestation_key = Util.calculate_attestation_key(account_subkey, block_height, account_id)
    hash = Util.leaf_hash(amount, attestation_key, leaf_idx)
    MerkleSumTree.Node.new(hash, amount)
  end

  @doc """
  sum_liabilities calculates the sum of a list of liabilities.
  """
  @spec sum_liabilities(list(Liability.t())) :: non_neg_integer()
  def sum_liabilities(liabilities) do
    Enum.reduce(liabilities, 0, fn liability, acc -> liability.amount + acc end)
  end
end
