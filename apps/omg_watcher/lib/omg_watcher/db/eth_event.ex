# Copyright 2019 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.DB.EthEvent do
  @moduledoc """
  Ecto schema for events logged by Ethereum: deposits and exits
  """
  use Ecto.Schema

  alias OMG.Crypto
  alias OMG.Eth.Encoding
  alias OMG.Utxo
  alias OMG.Watcher.DB

  require Utxo

  @primary_key {:rootchain_txhash, :binary, []}
  @derive {Phoenix.Param, key: :rootchain_txhash}
  schema "ethevents" do
    field(:event_type, OMG.Watcher.DB.Types.AtomType)

    many_to_many(
      :txoutputs,
      DB.TxOutput,
      join_through: "ethevents_txoutputs",
      join_keys: [rootchain_txhash: :rootchain_txhash, childchain_utxohash: :childchain_utxohash]
    )

    timestamps([type: :utc_datetime])
  end

  @doc """
  Inserts deposits based on a list of event maps (if not already inserted before)
  """
  @spec insert_deposits!([OMG.State.Core.deposit()]) :: :ok
  def insert_deposits!(deposits) do
    deposits |> Enum.each(&insert_deposit!/1)
  end

  @spec insert_deposit!(OMG.State.Core.deposit()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_deposit!(%{rootchain_txhash: rootchain_txhash, blknum: blknum, owner: owner, currency: currency, amount: amount}) do
    if existing_deposit = get(rootchain_txhash) != nil,
      do: {:ok, existing_deposit},
      else:
        %__MODULE__{
          rootchain_txhash: rootchain_txhash,
          event_type: :deposit,

          # a deposit from the rootchain will only ever have 1 childchain txoutput object
          txoutputs: [%DB.TxOutput{
            childchain_utxohash: Crypto.hash(rootchain_txhash),
            blknum: blknum,
            txindex: 0,
            oindex: 0,
            owner: owner,
            currency: currency,
            amount: amount
          }]
        }
        |> DB.Repo.insert()
  end

  @doc """
  Uses a list of encoded `Utxo.Position`s to insert the exits (if not already inserted before)
  """
  @spec insert_exits!([non_neg_integer()]) :: :ok
  def insert_exits!(exits) do
    exits
    |> Stream.map(&utxo_exit_from_exit_event/1)
    |> Enum.each(&insert_exit!/1)
  end

  @spec utxo_exit_from_exit_event(%{call_data: %{utxo_pos: pos_integer()}, rootchain_txhash: string()}) :: Utxo.Position.t()
  defp utxo_exit_from_exit_event(%{call_data: %{utxo_pos: utxo_pos}, rootchain_txhash: rootchain_txhash}) do
    %{rootchain_txhash: rootchain_txhash, decoded_utxo_position: Utxo.Position.decode!(utxo_pos)}
  end

  #@spec insert_exit!(Utxo.Position.t()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  defp insert_exit!(%{rootchain_txhash: rootchain_txhash, decoded_utxo_position: decoded_utxo_position} = utxo_exit) do
    if existing_exit = get(rootchain_txhash) != nil,
      do:  {:ok, existing_exit},
      else:
        exiting_utxo =
          DB.TxOutput.get_by_position(decoded_utxo_position)
          |> Map.put(:childchain_utxohash, Crypto.hash(rootchain_txhash))
          |> IO.inspect(label: "exiting_utxo:")

        %__MODULE__{
          rootchain_txhash: rootchain_txhash,
          event_type: :exit,

          # an exit from the rootchain will only ever have 1 childchain txoutput object
          txoutputs: [exiting_utxo]
        }
        |> DB.Repo.insert()
  end

  defp get(rootchain_txhash), do: DB.Repo.get(__MODULE__, rootchain_txhash)
end
