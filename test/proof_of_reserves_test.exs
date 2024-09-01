defmodule ProofOfReservesTest do
  use ExUnit.Case
  doctest ProofOfReserves

  alias ProofOfReserves.{Liabilities, Util}

  describe "split_liabilities/1" do
    test "empty list" do
      assert [] == ProofOfReserves.split_liabilities([], 100_000)
    end

    test "indivisible singleton" do
      liabilities = [
        Liabilities.fake_liability(1)
      ]

      full_liabilities = ProofOfReserves.split_liabilities(liabilities, 100_000)
      assert full_liabilities == liabilities
    end

    test "singleton" do
      liability_maximum_threshold_sat = 5_000_000
      # this guarantees even after the mandatory first split, we still have to split
      # due to the max threshold rule.
      amount = liability_maximum_threshold_sat * 2 + 1

      liabilities = [
        Liabilities.fake_liability(amount)
      ]

      full_liabilities = ProofOfReserves.split_liabilities(liabilities, liability_maximum_threshold_sat)
      assert length(full_liabilities) >= 4

      Enum.each(full_liabilities, fn liability ->
        assert liability.amount <= liability_maximum_threshold_sat
      end)
    end

    test "test rule order behavior" do
      # 3 liabilities -> 8 liabilities
      # due to the splitting rules, we have to split each liability once first
      # and then split them until we reach a power of two
      liabilities = [
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(2),
        Liabilities.fake_liability(3)
      ]

      full_liabilities = ProofOfReserves.split_liabilities(liabilities, 100_000)

      assert length(full_liabilities) == 8

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

    test "test threshold" do
      liability_maximum_threshold_sat = 5_000_000
      amount = liability_maximum_threshold_sat * 2

      # 2 @ 2x threshold -> 4, with 2 over threshold -> 6 -> 8
      liabilities = [
        Liabilities.fake_liability(amount),
        Liabilities.fake_liability(amount)
      ]

      full_liabilities = ProofOfReserves.split_liabilities(liabilities, liability_maximum_threshold_sat)

      # we won't know the exact amount of liabilities, but we know it's at least 8
      assert length(full_liabilities) > 4

      Enum.each(full_liabilities, fn liability ->
        # ensure no Dummy zero-amount liabilities were added
        assert Util.bin_to_hex!(liability.account_subkey) ==
                 Liabilities.fake_liability_account_subkey()

        # ensure all liabilities are below the threshold
        assert liability.amount <= liability_maximum_threshold_sat
      end)
    end
  end

  describe "build_liabilities_tree/2" do
    setup do
      {:ok, block_height: 1000, liability_maximum_threshold_sat: 5_000_000}
    end

    test "empty list", %{
      block_height: block_height,
      liability_maximum_threshold_sat: liability_maximum_threshold_sat
    } do
      assert [] == ProofOfReserves.build_liabilities_tree(block_height, [], liability_maximum_threshold_sat)
    end

    test "indivisible singleton", %{
      block_height: block_height,
      liability_maximum_threshold_sat: liability_maximum_threshold_sat
    } do
      liabilities = [
        liability = Liabilities.fake_liability(1)
      ]

      leaf = Liabilities.liability_to_node(block_height, 0, liability)

      assert [[leaf]] ==
               ProofOfReserves.build_liabilities_tree(
                 block_height,
                 liabilities,
                 liability_maximum_threshold_sat
               )
    end

    test "singleton", %{
      block_height: block_height,
      liability_maximum_threshold_sat: liability_maximum_threshold_sat
    } do
      liabilities = [
        Liabilities.fake_liability(2)
      ]

      leaf0 = Liabilities.liability_to_node(block_height, 0, Liabilities.fake_liability(1))
      leaf1 = Liabilities.liability_to_node(block_height, 1, Liabilities.fake_liability(1))

      # assert sum matches & two leaves are in correct order
      [[%ProofOfReserves.MerkleSumTree.Node{value: 2, hash: hash}], [^leaf0, ^leaf1]] =
        ProofOfReserves.build_liabilities_tree(block_height, liabilities, liability_maximum_threshold_sat)

      assert Util.bin_to_hex!(hash) ==
               "0000c1d0b830134f958a5be3fac281a25e3c134741228c00394cc8cbafa70351"
    end

    test "4 liabilities", %{
      block_height: block_height,
      liability_maximum_threshold_sat: liability_maximum_threshold_sat
    } do
      # 4 nodes -> 7 after each is split once -> 8 after one more split
      # since they are shuffled we can't predict the exact order
      # but the amounts should be 1,1,1,1,1,1,x,x
      liabilities = [
        _lb1 = Liabilities.fake_liability(1),
        _lb2 = Liabilities.fake_liability(2),
        _lb3 = Liabilities.fake_liability(3),
        _lb4 = Liabilities.fake_liability(4)
      ]

      [
        [%ProofOfReserves.MerkleSumTree.Node{value: 10}],
        [_n0, _n1],
        [_n00, _n01, _n10, _n11],
        [_leaf0, _leaf1, _leaf2, _leaf3, _leaf4, _leaf5, _leaf6, _leaf7]
      ] = ProofOfReserves.build_liabilities_tree(block_height, liabilities, liability_maximum_threshold_sat)
    end

    test "5 liabilities", %{
      block_height: block_height,
      liability_maximum_threshold_sat: liability_maximum_threshold_sat
    } do
      liabilities = [
        Liabilities.fake_liability(1),
        Liabilities.fake_liability(2),
        Liabilities.fake_liability(3),
        Liabilities.fake_liability(4),
        Liabilities.fake_liability(5)
      ]

      [[%ProofOfReserves.MerkleSumTree.Node{value: 15}] | _] =
        ProofOfReserves.build_liabilities_tree(block_height, liabilities, liability_maximum_threshold_sat)
    end
  end

  describe "find_account_leaves/2 & get_account_balance/2" do
    setup do
      {:ok, block_height: 1000, liability_maximum_threshold_sat: 5_000_000}
    end

    test "test getting balance", %{
      block_height: block_height,
      liability_maximum_threshold_sat: liability_maximum_threshold_sat
    } do
      acct_id = 1234

      acct_key =
        Util.hex_to_bin!("abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234")

      liabilities = [
        Liabilities.fake_liability(1),
        # create a liability with a different account_id so
        # we can test that the function only returns the leaves
        ProofOfReserves.Liability.new(
          acct_id,
          acct_key,
          2
        ),
        Liabilities.fake_liability(3),
        Liabilities.fake_liability(4),
        Liabilities.fake_liability(5)
      ]

      tree =
        ProofOfReserves.build_liabilities_tree(block_height, liabilities, liability_maximum_threshold_sat)

      leaves = ProofOfReserves.MerkleSumTree.get_leaves(tree)
      my_leaves = ProofOfReserves.find_account_leaves(leaves, block_height, acct_id, acct_key)
      assert length(my_leaves) == 2

      attestation_key = Util.calculate_attestation_key(acct_key, block_height, acct_id)

      my_balance = ProofOfReserves.get_account_balance(tree, attestation_key)
      assert my_balance == 2
    end

    test "test larger balance", %{
      block_height: block_height,
      liability_maximum_threshold_sat: liability_maximum_threshold_sat
    } do
      acct_id = 1234

      acct_key =
        Util.hex_to_bin!("abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234")

      balance = liability_maximum_threshold_sat * 2 + 1

      liabilities = [
        Liabilities.fake_liability(1),
        # create a liability with a different account_id so
        # we can test that the function only returns the leaves
        ProofOfReserves.Liability.new(
          acct_id,
          acct_key,
          balance
        ),
        Liabilities.fake_liability(3),
        Liabilities.fake_liability(4),
        Liabilities.fake_liability(5),
        Liabilities.fake_liability(1000),
        Liabilities.fake_liability(2000),
        Liabilities.fake_liability(4000)
      ]

      tree =
        ProofOfReserves.build_liabilities_tree(block_height, liabilities, liability_maximum_threshold_sat)

      leaves = ProofOfReserves.MerkleSumTree.get_leaves(tree)
      my_leaves = ProofOfReserves.find_account_leaves(leaves, block_height, acct_id, acct_key)
      # we can't predict the exact number of leaves, but we know it's at least 3
      assert length(my_leaves) >= 3

      attestation_key = Util.calculate_attestation_key(acct_key, block_height, acct_id)

      my_balance = ProofOfReserves.get_account_balance(tree, attestation_key)
      assert my_balance == balance
    end
  end
end
