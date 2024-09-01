defmodule ProofOfReserves.LiabilitiesTest do
  use ExUnit.Case

  alias ProofOfReserves.{Liabilities, MerkleSumTree, Util}

  describe "split_liabilities_to_power_of_two/1" do
    test "regular" do
      # 0 liabilities -> 0 liabilities
      assert [] == Liabilities.split_liabilities_to_power_of_two([])

      # 1 liability -> 1 liability
      liabilities = [
        Liabilities.fake_liability(2)
      ]

      full_liabilities = Liabilities.split_liabilities_to_power_of_two(liabilities)
      assert full_liabilities == liabilities

      # 2 liabilities -> 2 liabilities
      liabilities = [
        Liabilities.fake_liability(2),
        Liabilities.fake_liability(4)
      ]

      full_liabilities = Liabilities.split_liabilities_to_power_of_two(liabilities)
      assert full_liabilities == liabilities

      # 5 liabilities -> 8 liabilities
      liabilities = [
        Liabilities.fake_liability(100),
        Liabilities.fake_liability(200),
        Liabilities.fake_liability(300),
        Liabilities.fake_liability(400),
        Liabilities.fake_liability(500)
      ]

      full_liabilities = Liabilities.split_liabilities_to_power_of_two(liabilities)

      assert length(full_liabilities) == 8
    end

    test "split to power of two using rest of liabilities" do
      # 3 liabilities -> 4 liabilities
      liabilities = [
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(2),
        Liabilities.fake_liability(3)
      ]

      full_liabilities = Liabilities.split_liabilities_to_power_of_two(liabilities)

      assert length(full_liabilities) == 4

      assert full_liabilities == [
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(3)
             ]

      # 6 liabilities -> 8 liabilities
      liabilities = [
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(2),
        # to make the test more easily determinable, this is 2-amount
        Liabilities.fake_liability(2),
        Liabilities.fake_liability(4),
        Liabilities.fake_liability(5),
        Liabilities.fake_liability(6)
      ]

      full_liabilities = Liabilities.split_liabilities_to_power_of_two(liabilities)

      assert length(full_liabilities) == 8

      assert full_liabilities == [
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(4),
               Liabilities.fake_liability(5),
               Liabilities.fake_liability(6)
             ]

      # 5 liabilities -> 8 liabilities
      # this test checks that the rest of the liabilities are splitd
      # and that a dummy is filled in if necessary
      liabilities = [
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(2),
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(2),
        Liabilities.fake_liability(1)
      ]

      full_liabilities = Liabilities.split_liabilities_to_power_of_two(liabilities)

      assert length(full_liabilities) == 8

      assert full_liabilities == [
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.dummy_liability()
             ]
    end

    test "split to power of two not possible due to amounts" do
      liabilities = [
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(2)
      ]

      full_liabilities = Liabilities.split_liabilities_to_power_of_two(liabilities)

      assert length(full_liabilities) == 8

      # in this case, we have to add zero-amount
      # liabilities to reach the next power of two
      # but first we split the 2-amount liability
      assert full_liabilities == [
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.fake_liability(1),
               Liabilities.dummy_liability(),
               Liabilities.dummy_liability()
             ]
    end
  end

  describe "serialize/parse file symmetry" do
    test "test file" do
      filename = "test/data/test.csv"

      stream = File.stream!(filename)

      {block_height, merkle_tree} = Liabilities.parse_liabilities(stream)

      assert block_height == 420
      # 3 levels
      assert Enum.count(merkle_tree) == 3
      {:ok, root} = MerkleSumTree.get_tree_root(merkle_tree)

      assert MerkleSumTree.verify_tree?(merkle_tree)

      assert MerkleSumTree.Node.new(
               Util.hex_to_bin!(
                 "60f88b597c9fa10bd1d8e2fc6ba59b2f9a47913735d31a07e95c7d465e28d8b2"
               ),
               1_000_643_641_021
             ) == root

      text = Liabilities.serialize_liabilities(block_height, merkle_tree)

      Enum.reduce(stream, text, fn line, text ->
        assert ^line <> text = text
        text
      end)
    end
  end
end
