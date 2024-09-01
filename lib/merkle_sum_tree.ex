defmodule ProofOfReserves.MerkleSumTree do
  @moduledoc """
  MerkleSumTree is a module that represents a Merkle Sum Tree. It is used to calculate a Proof of Liabilities.
  In this module, a Node struct can represent a leaf or a branch. But when a variable is named leaves, it refers to the lowest level of the tree.
  """
  alias ProofOfReserves.{Node, Util}

  defmodule Node do
    @moduledoc """
    Node represents a node in a Merkle Sum Tree. It has a hash and a value.
    """
    alias ProofOfReserves.Util

    defstruct [:hash, :value]

    @type t :: %__MODULE__{
            hash: binary(),
            value: non_neg_integer()
          }

    @doc """
    new creates a new node with the given hash and value.
    """
    @spec new(binary(), non_neg_integer()) :: t()
    def new(hash, value) do
      %__MODULE__{
        hash: hash,
        value: value
      }
    end

    @doc """
    merkleize_nodes takes two nodes and combines them into a new node.
    """
    @spec merkleize_nodes(list(t())) :: t()
    def merkleize_nodes([
          %{hash: left_hash, value: left_value},
          %{hash: right_hash, value: right_value}
        ])
        when left_value >= 0 and right_value >= 0 do
      root_hash =
        (left_hash <>
           Util.int_to_little(left_value, 8) <> right_hash <> Util.int_to_little(right_value, 8))
        |> Util.sha256()

      new(root_hash, left_value + right_value)
    end

    @doc """
    serialize_node serializes a node into a string of "hash,value".
    """
    @spec serialize_node(t()) :: String.t()
    def serialize_node(%{hash: hash, value: value}) do
      "#{Util.bin_to_hex!(hash)},#{value}"
    end

    @doc """
    parse_node parses a string of "hash,value" into a Node.
    value is trimmed of leading and trailing whitespace before
    being converted to an integer.
    """
    @spec parse_node(String.t()) :: t()
    def parse_node(node) do
      [hash, value] = String.split(node, ",")
      new(Util.hex_to_bin!(hash), Util.str_to_int(value))
    end
  end

  defimpl Inspect, for: Node do
    alias ProofOfReserves.Util

    def inspect(%Node{hash: hash, value: value}, _opts) do
      "%Node{value: #{value}, hash: #{Util.abbr_hash(hash)}}"
    end
  end

  @type tree :: list(list(Node.t()))

  @doc """
  get_tree_root returns the root of a tree if it is complete.
  """
  @spec get_tree_root(tree()) :: {:ok, Node.t()} | {:error, String.t()}
  def get_tree_root([[%Node{} = root]]), do: {:ok, root}
  def get_tree_root([[%Node{} = root] | _tree]), do: {:ok, root}

  def get_tree_root([]), do: nil

  def get_tree_root(_tree) do
    {:error, "Tree is not complete. Root not found."}
  end

  @doc """
  get_leaves returns the leaves (the lowest level) of a tree.
  """
  @spec get_leaves(tree()) :: list(Node.t())
  def get_leaves(tree) do
    List.last(tree)
  end

  @doc """
  merkleize_one_level takes a list of nodes and combines them into a new list of nodes which will be half the size.
  """
  @spec merkleize_one_level(list(Node.t())) :: list(Node.t())
  def merkleize_one_level(nodes) do
    nodes
    |> Enum.chunk_every(2)
    |> Enum.map(&Node.merkleize_nodes/1)
  end

  @doc """
  build_merkle_tree builds a Merkle Sum Tree from a list of leaves.
  Returns an error if the number of leaves is not a power of 2.
  """
  @spec build_merkle_tree(list(Node.t())) :: tree() | {:error, String.t()}
  def build_merkle_tree(leaves) do
    leaves
    |> length()
    |> Util.is_power_of_two?()
    |> case do
      true -> do_build_merkle_tree([leaves])
      _ -> {:error, "Number of leaves is not a power of 2."}
    end
  end

  # when there's zero or one node left, the tree is complete
  @spec do_build_merkle_tree(tree()) :: tree()
  defp do_build_merkle_tree([[]]), do: []
  defp do_build_merkle_tree([[_root]] = tree), do: tree
  defp do_build_merkle_tree([[_root] | _rest] = tree), do: tree

  defp do_build_merkle_tree([nodes | _] = rest) do
    do_build_merkle_tree([merkleize_one_level(nodes) | rest])
  end

  @doc """
  serialize_tree serializes a tree into a list of strings, where each string represents a node.
  This is a breadth first serialization, where each level is serialized in order.
  """
  @spec serialize_tree(tree()) :: String.t()
  def serialize_tree(tree) do
    tree
    |> Enum.map(fn lvl ->
      serialize_level(lvl)
    end)
    |> Enum.join("")
  end

  # serialize a level of nodes. This is a helper function for serialize_tree
  @spec serialize_level(list(Node.t())) :: String.t()
  defp serialize_level(level) do
    level
    |> Enum.map(&Node.serialize_node/1)
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end

  @doc """
  parse_tree parses a stream of serialized Node strings into a tree.
  """
  # @spec parse_tree(Stream.t()) :: tree()
  def parse_tree(stream) do
    stream
    |> do_parse_tree(1, [])
    |> Enum.reverse()
  end

  # @spec do_parse_tree(Stream.t(), non_neg_integer(), tree()) :: tree()
  defp do_parse_tree(stream, row_count, tree) do
    case Enum.take(stream, row_count) do
      [] ->
        tree

      row ->
        parsed_row = Enum.map(row, &Node.parse_node/1)
        do_parse_tree(Enum.drop(stream, row_count), row_count * 2, [parsed_row | tree])
    end
  end

  @doc """
  verify_tree? rebuilds the entire tree and compares the root and the height of the tree.
  """
  @spec verify_tree?(tree()) :: boolean()
  def verify_tree?([[root] | _] = tree) do
    # just rebuild the tree and compare the root and the height
    [[new_root] | _] =
      new_tree =
      tree
      |> get_leaves()
      |> build_merkle_tree()

    root == new_root && length(tree) == length(new_tree)
  end
end
