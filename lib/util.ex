defmodule ProofOfReserves.Util do
  import Bitwise, only: [&&&: 2, <<<: 2]

  @doc """
  sha256 calculates the sha256 hash of the given data.
  """
  @spec sha256(iodata()) :: <<_::256>>
  def sha256(data) do
    :crypto.hash(:sha256, data)
  end

  @doc """
  sha256hmac calculates the sha256 hmac of the given key and message.
  """
  @spec sha256hmac(iodata(), iodata()) :: binary
  def sha256hmac(key, msg) do
    :crypto.mac(:hmac, :sha256, key, msg)
  end

  @doc """
  hex_to_bin! converts a lowercase hex string to a binary.
  """
  @spec hex_to_bin!(String.t()) :: binary
  def hex_to_bin!(hex) do
    Base.decode16!(hex, case: :lower)
  end

  @doc """
  bin_to_hex! converts a binary to a lowercase hex string.
  """
  def bin_to_hex!(bin) do
    Base.encode16(bin, case: :lower)
  end

  @doc """
  base32_to_int! converts a base32 string to an integer.
  """
  @spec base32_to_int!(String.t()) :: non_neg_integer()
  def base32_to_int!(base32) do
    base32
    |> Base.decode32!(padding: false)
    |> :binary.decode_unsigned()
  end

  @doc """
  int_to_little converts an integer to a little-endian binary.
  """
  @spec int_to_little(non_neg_integer(), integer) :: binary
  def int_to_little(i, p) do
    i
    |> :binary.encode_unsigned(:little)
    |> pad(p, :trailing)
  end

  @typedoc """
    The pad_type describes the padding to use.
  """
  @type pad_type :: :leading | :trailing

  @doc """
  pads binary according to the byte length and the padding type. A binary can be padded with leading or trailing zeros.
  """
  @spec pad(bin :: binary, byte_len :: integer, pad_type :: pad_type) :: binary
  def pad(bin, byte_len, _pad_type) when is_binary(bin) and byte_size(bin) == byte_len do
    bin
  end

  def pad(bin, byte_len, pad_type) when is_binary(bin) and pad_type == :leading do
    pad_len = 8 * byte_len - byte_size(bin) * 8
    <<0::size(pad_len)>> <> bin
  end

  def pad(bin, byte_len, pad_type) when is_binary(bin) and pad_type == :trailing do
    pad_len = 8 * byte_len - byte_size(bin) * 8
    bin <> <<0::size(pad_len)>>
  end

  @doc """
  str_to_int converts a string to an integer.
  """
  @spec str_to_int(String.t()) :: integer
  def str_to_int(str) do
    str
    |> String.trim()
    |> String.to_integer()
  end

  @doc """
  crypto_rand_int generates a random 64-bit unsigned integer.
  """
  @spec crypto_rand_int() :: non_neg_integer()
  def crypto_rand_int() do
    :crypto.strong_rand_bytes(8)
    |> :binary.decode_unsigned(:big)
  end

  @doc """
  Replaces all but the first and last 2 bytes of a hash with "...".
  """
  @spec abbr_hash(binary) :: String.t()
  def abbr_hash(hash) do
    hex = bin_to_hex!(hash)
    String.slice(hex, 0..4) <> "..." <> String.slice(hex, -4..-1)
  end

  @doc """
  is_power_of_two? returns true if the given number is a power of two.
  """
  @spec is_power_of_two?(non_neg_integer()) :: boolean
  def is_power_of_two?(n) do
    (n &&& n - 1) == 0
  end

  @doc """
  next_power_of_two returns the closest (larger) power of two to the given number.
  Note: this function returns the next power of two, not the closest.
  """
  @spec next_power_of_two(pos_integer()) :: non_neg_integer()
  def next_power_of_two(n) do
    if is_power_of_two?(n) do
      n
    else
      bits =
        n
        |> Integer.to_string(2)
        |> String.length()

      1 <<< bits
    end
  end

  @doc """
  calculate_account_subkey generates the subkey for an account.
  account_subkey = sha256(account_key || email || account_id)
  account_key is a 32-byte binary, not a hex String.
  email is a String, which is UTF-8 encoded and thus needs no
  special handling before hashing
  """
  @spec calculate_account_subkey(binary(), String.t(), non_neg_integer()) :: binary
  def calculate_account_subkey(account_key, email, account_id) do
    (account_key <> email <> int_to_little(account_id, 8))
    |> sha256()
  end

  @doc """
  calculate_attestation_key generates the attestation key for the account in a specific attestation.
  attestation_key = sha256(account_subkey || block_height || account_id)
  block_height and account_id must be 8-byte ints.
  """
  @spec calculate_attestation_key(
          account_subkey :: String.t(),
          block_height :: non_neg_integer,
          account_id :: non_neg_integer
        ) :: binary
  def calculate_attestation_key(account_subkey, block_height, account_id) do
    (account_subkey <> int_to_little(block_height, 8) <> int_to_little(account_id, 8))
    |> sha256()
  end

  @doc """
  leaf_hash calculates the hash of a leaf in the Merkle Sum Tree.
  """
  @spec leaf_hash(non_neg_integer, binary, non_neg_integer) :: binary
  def leaf_hash(value, attestation_key, leaf_index) do
    msg = int_to_little(value, 8) <> int_to_little(leaf_index, 8)
    sha256hmac(attestation_key, msg)
  end

  def sats_to_btc(sats) do
    sats / 100_000_000
  end
end
