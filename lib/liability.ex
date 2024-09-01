defmodule ProofOfReserves.Liability do
  @moduledoc """
  A liability is a financial obligation that a company has to a user account.
  Liabilities are calculated on an account basis.

  BitMEX calls the account_subkey an account_nonce, but we renamed it account_subkey
  since it is not in fact a nonce, and is long-lived and derived from the account's
  root key, email, and account_id.
  """
  defstruct [
    :account_id,
    :account_subkey,
    :amount
  ]

  # @enforce_keys [:account_id, :account_subkey, :amount]

  @type t :: %__MODULE__{
          account_id: non_neg_integer(),
          account_subkey: binary(),
          amount: non_neg_integer()
        }

  @doc """
  new returns a new Liability
  """
  @spec new(non_neg_integer(), binary(), non_neg_integer()) :: t()
  def new(account_id, account_subkey, amount) do
    %__MODULE__{
      account_id: account_id,
      account_subkey: account_subkey,
      amount: amount
    }
  end
end

defimpl Inspect, for: ProofOfReserves.Liability do
  alias ProofOfReserves.Util

  def inspect(
        %ProofOfReserves.Liability{account_id: account_id, account_subkey: account_subkey, amount: amount},
        _opts
      ) do
    "%Liability{account_id: #{account_id}, amount: #{amount}, account_subkey: #{Util.abbr_hash(account_subkey)}}"
  end
end
