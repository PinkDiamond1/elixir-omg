defmodule OmisegoWalletWeb.Controller.Utxo do
  @moduledoc """
  """
  alias OmisegoWallet.{Repo, TransactionDB}
  use OmisegoWalletWeb, :controller
  import Ecto.Query, only: [from: 2]
  alias OmiseGO.API.{Block}
  alias OmiseGO.API.State.{Transaction, Transaction.Signed}

  defp consume_transaction(
         %Signed{
           raw_tx: %Transaction{} = transaction
         } = signed_transaction,
         txindex,
         block_number
       ) do
    # TODO change this to encode from OmiseGo.API.State.Transaction
    txbyte = inspect(signed_transaction)

    make_transaction_db = fn transaction, number ->
      %TransactionDB{
        addres: Map.get(transaction, :"newowner#{number}"),
        amount: Map.get(transaction, :"amount#{number}"),
        blknum: block_number,
        oindex: Map.get(transaction, :"oindex#{number}"),
        txbyte: txbyte,
        txindex: txindex
      }
    end

    {Repo.insert(make_transaction_db.(transaction, 1)),
     Repo.insert(make_transaction_db.(transaction, 2))}
  end

  defp remove_utxo(%Signed{
         raw_tx: %Transaction{} = transaction
       }) do
    remove_from = fn transaction, number ->
      txindex = Map.get(transaction, :"txindex#{number}")
      blknum = Map.get(transaction, :"blknum#{number}")
      oindex = Map.get(transaction, :"oindex#{number}")

      elements_to_remove = from(
        transactionDb in TransactionDB,
        where:
          transactionDb.txindex == ^txindex and transactionDb.blknum == ^blknum and
            transactionDb.oindex == ^oindex
      )
      elements_to_remove |> Repo.delete_all()
    end

    {remove_from.(transaction, 1), remove_from.(transaction, 2)}
  end

  def consume_block(%Block{transactions: transactions}, block_number) do
    numbered_transactions = Stream.with_index(transactions)

    numbered_transactions
    |> Stream.map(fn {%Signed{} = signed, txindex} ->
      {remove_utxo(signed), consume_transaction(signed, txindex, block_number)}
    end)
    |> Enum.to_list()
  end

  def available(conn, %{"addres" => addres}) do
    transactions = Repo.all(from(tr in TransactionDB, where: tr.addres == ^addres, select: tr))
    fields_names = List.delete(TransactionDB.field_names(), :addres)

    json(conn, %{
      addres: addres,
      utxos: Enum.map(transactions, &Map.take(&1, fields_names))
    })
  end
end
