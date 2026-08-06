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

  describe "crypto_rand_uniform/1" do
    test "n = 1 always returns 1" do
      Enum.each(1..100, fn _ -> assert Util.crypto_rand_uniform(1) == 1 end)
    end

    test "stays within 1..n, including at byte boundaries" do
      ns = [2, 3, 4, 255, 256, 257, 65_535, 65_536, 65_537, 100_000_000, 2_100_000_000_000_000]

      Enum.each(ns, fn n ->
        Enum.each(1..500, fn _ ->
          x = Util.crypto_rand_uniform(n)
          assert x >= 1 and x <= n, "#{x} is outside 1..#{n}"
        end)
      end)
    end

    test "covers the whole range" do
      draws = for _ <- 1..2_000, do: Util.crypto_rand_uniform(4)
      assert Enum.sort(Enum.uniq(draws)) == [1, 2, 3, 4]
    end

    test "rejection sampling removes modulo bias at a byte boundary" do
      # n = 255 drawn from one byte is the classic biased case: a naive
      # rem(v, 255) + 1 would make 1 twice as likely as every other value.
      n = 255
      trials = n * 400
      expected = trials / n

      counts =
        for(_ <- 1..trials, do: Util.crypto_rand_uniform(n))
        |> Enum.frequencies()

      ones = Map.fetch!(counts, 1)

      assert ones < expected * 1.5,
             "value 1 appeared #{ones} times, expected ~#{expected} (modulo bias?)"
    end

    test "is approximately uniform" do
      n = 4
      trials = 40_000
      expected = trials / n

      counts =
        for(_ <- 1..trials, do: Util.crypto_rand_uniform(n))
        |> Enum.frequencies()

      Enum.each(1..n, fn v ->
        count = Map.fetch!(counts, v)

        assert abs(count - expected) < expected * 0.1,
               "value #{v} appeared #{count} times, expected ~#{expected}"
      end)
    end

    test "is not reproducible from a :rand seed" do
      # Regression test: the draw must not come from :rand, whose stream is
      # replayable by anyone who can guess the process seed.
      :rand.seed(:exsss, {1, 2, 3})
      a = for _ <- 1..20, do: Util.crypto_rand_uniform(1_000_000_000)

      :rand.seed(:exsss, {1, 2, 3})
      b = for _ <- 1..20, do: Util.crypto_rand_uniform(1_000_000_000)

      refute a == b
    end
  end
end
