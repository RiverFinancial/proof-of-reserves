defmodule ProofOfReserves.UtilTest do
  use ExUnit.Case

  alias ProofOfReserves.{Util}

  describe "math functions" do
    test "is_power_of_two?/1" do
      # powers of two
      # for our purposes, this math edge case is okay
      # because in an empty tree, we can't add any liabilities
      assert Util.is_power_of_two?(0)
      assert Util.is_power_of_two?(1)
      assert Util.is_power_of_two?(2)
      assert Util.is_power_of_two?(4)
      assert Util.is_power_of_two?(8)
      assert Util.is_power_of_two?(16)
      assert Util.is_power_of_two?(32)
      assert Util.is_power_of_two?(64)
      # 2^32
      assert Util.is_power_of_two?(4_294_967_296)

      # not powers of two
      assert !Util.is_power_of_two?(3)
      assert !Util.is_power_of_two?(5)
      assert !Util.is_power_of_two?(6)
      assert !Util.is_power_of_two?(255)
    end

    test "next_power_of_two/1" do
      assert Util.next_power_of_two(1) == 1
      assert Util.next_power_of_two(2) == 2
      assert Util.next_power_of_two(3) == 4
      assert Util.next_power_of_two(4) == 4
      assert Util.next_power_of_two(5) == 8
      assert Util.next_power_of_two(6) == 8
      assert Util.next_power_of_two(7) == 8
      assert Util.next_power_of_two(8) == 8
      assert Util.next_power_of_two(9) == 16
    end
  end
end
