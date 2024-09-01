defmodule ProofOfReserves.MerkleSumTreeTest do
  use ExUnit.Case

  alias ProofOfReserves.{MerkleSumTree, Util}

  @moduletag timeout: 600_000

  describe "merkleize_nodes" do
    test "merkleizes two nodes" do
      # hash of int 0
      a =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"),
          1
        )

      # hash of int 1
      b =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"),
          2
        )

      expected =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("edfc68f633fdf3d357f8bbbd1085a9874a994a5473739fadefd04406f30e53db"),
          3
        )

      assert expected == MerkleSumTree.Node.merkleize_nodes([a, b])
    end

    test "fails when 1 value is negative" do
      a =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"),
          1
        )

      b =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"),
          -2
        )

      assert_raise FunctionClauseError, fn ->
        MerkleSumTree.Node.merkleize_nodes([a, b])
      end
    end
  end

  describe "get_tree_root/1" do
    test "returns the root of a complete tree" do
      leaves = [
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("5452c381101d20029bc3effd5fef26f828e6e9b55476aa83fae45ef79d8090d1"),
          12344
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
          62034
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
          643_566_644
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("56845bdfa09b53bebc29fb34045c15f66875ca8abef2a3083689eb88fb2cbd51"),
          999_999_999_999
        )
      ]

      tree = MerkleSumTree.build_merkle_tree(leaves)
      sum = 1_000_643_641_021
      hash = Util.hex_to_bin!("60f88b597c9fa10bd1d8e2fc6ba59b2f9a47913735d31a07e95c7d465e28d8b2")

      assert {:ok, %MerkleSumTree.Node{value: sum, hash: hash}} ==
               MerkleSumTree.get_tree_root(tree)
    end

    test "returns an error for an incomplete tree" do
      leaves = [
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("5452c381101d20029bc3effd5fef26f828e6e9b55476aa83fae45ef79d8090d1"),
          12344
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
          62034
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
          643_566_644
        )
      ]

      tree = [leaves]

      assert {:error, "Tree is not complete. Root not found."} ==
               MerkleSumTree.get_tree_root(tree)

      tree = [
        [
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("5452c381101d20029bc3effd5fef26f828e6e9b55476aa83fae45ef79d8090d1"),
            12344
          ),
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
            62034
          )
        ],
        [
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
            643_566_644
          ),
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
            643_566_644
          ),
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
            643_566_644
          ),
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
            643_566_644
          )
        ]
      ]

      assert {:error, "Tree is not complete. Root not found."} ==
               MerkleSumTree.get_tree_root(tree)
    end

    test "returns nil for an empty tree" do
      assert nil == MerkleSumTree.get_tree_root([])
    end
  end

  describe "build_merkle_tree/1" do
    test "builds a merkle tree" do
      leaves = [
        a =
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("5452c381101d20029bc3effd5fef26f828e6e9b55476aa83fae45ef79d8090d1"),
            12344
          ),
        b =
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
            62034
          ),
        c =
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
            643_566_644
          ),
        d =
          MerkleSumTree.Node.new(
            Util.hex_to_bin!("56845bdfa09b53bebc29fb34045c15f66875ca8abef2a3083689eb88fb2cbd51"),
            999_999_999_999
          )
      ]

      left =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("a6c12941552b8dfd8b51cfcc342cf35e455d4c39002420e0f225fdcd3bffa1eb"),
          a.value + b.value
        )

      right =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("55c064675cc1a30a9948844a04e9e300967a62719997c7801e3c9b566eb6282b"),
          c.value + d.value
        )

      root =
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("60f88b597c9fa10bd1d8e2fc6ba59b2f9a47913735d31a07e95c7d465e28d8b2"),
          left.value + right.value
        )

      tree = MerkleSumTree.build_merkle_tree(leaves)
      [[^root], [^left, ^right], [^a, ^b, ^c, ^d]] = tree
    end

    test "fails due to non power of 2 leaves" do
      # empty tree
      assert [] == MerkleSumTree.build_merkle_tree([])

      # 3 leaves
      leaves = [
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("5452c381101d20029bc3effd5fef26f828e6e9b55476aa83fae45ef79d8090d1"),
          12344
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
          62034
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
          643_566_644
        )
      ]

      assert {:error, "Number of leaves is not a power of 2."} ==
               MerkleSumTree.build_merkle_tree(leaves)

      # even number of leaves
      leaves = [
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("5452c381101d20029bc3effd5fef26f828e6e9b55476aa83fae45ef79d8090d1"),
          12344
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
          62034
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("9f4da6f1175c81bae6a4de481bda6211b393d752c104c6b2df057fb72364ccc7"),
          643_566_644
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("5452c381101d20029bc3effd5fef26f828e6e9b55476aa83fae45ef79d8090d1"),
          12344
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
          62034
        ),
        MerkleSumTree.Node.new(
          Util.hex_to_bin!("84c37f78d32e46a492f94c8d4742fea5d80187b637ee3042e9beb6c01121c2d3"),
          62034
        )
      ]

      assert {:error, "Number of leaves is not a power of 2."} ==
               MerkleSumTree.build_merkle_tree(leaves)
    end
  end

  describe "verify_tree?/1" do
    test "test file" do
      stream = File.stream!("test/data/test.csv")

      merkle_tree =
        stream
        |> Stream.drop(1)
        |> MerkleSumTree.parse_tree()

      assert MerkleSumTree.verify_tree?(merkle_tree)
    end

    # test "bitmex example file" do
    #   stream = File.stream!("test/data/20240618-liabilities-848470-20240618D100000.058936337.csv")

    #   merkle_tree =
    #     stream
    #     |> Stream.drop(1)
    #     |> MerkleSumTree.parse_tree()

    #   assert MerkleSumTree.verify_tree?(merkle_tree)
    # end
  end

  describe "parse/serialize symmetry" do
    test "test file" do
      filename = "test/data/test.csv"

      stream =
        File.stream!(filename)
        |> Stream.drop(1)

      merkle_tree = MerkleSumTree.parse_tree(stream)

      text = MerkleSumTree.serialize_tree(merkle_tree)

      Enum.reduce(stream, text, fn line, text ->
        assert ^line <> text = text
        text
      end)
    end

    # test "read bitmex example file" do
    #   filename = "test/data/20240618-liabilities-848470-20240618D100000.058936337.csv"
    #   stream =
    #     filename
    #     |> File.stream!()
    #     |> Stream.drop(1)
    #   merkle_tree = MerkleSumTree.parse_tree(stream)

    #   text = MerkleSumTree.serialize_tree(merkle_tree)

    #   # check each line in the file
    #   Enum.reduce(stream, text, fn line, text ->
    #     assert ^line <> text = text
    #     text
    #   end)
    # end

    # test "read bitmex file, rebuild from leaves" do
    #   filename = "test/data/20240618-liabilities-848470-20240618D100000.058936337.csv"
    #   stream =
    #     filename
    #     |> File.stream!()
    #     |> Stream.drop(1)
    #   merkle_tree = MerkleSumTree.parse_tree(stream)

    #   leaves = MerkleSumTree.get_leaves(merkle_tree)

    #   rebuilt_tree = MerkleSumTree.build_merkle_tree(leaves)

    #   # these are taken from the file
    #   value = 5465201132265
    #   hash = Util.hex_to_bin!("a0543777c6e0456ffbeb093a0b8aced203b932f48cf8df15b4f5707c07c2a606")

    #   {:ok, %MerkleSumTree.Node{value: ^value, hash: ^hash}} = MerkleSumTree.get_tree_root(merkle_tree)
    #   {:ok, %MerkleSumTree.Node{value: ^value, hash: ^hash}} = MerkleSumTree.get_tree_root(rebuilt_tree)
    # end
  end
end
