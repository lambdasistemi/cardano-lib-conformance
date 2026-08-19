import scalus.cardano.ledger.{Transaction, Value}
import scalus.cardano.txbuilder.{DiffHandler, TxBalancingError}

object OuterLoop:
  final case class NonConvergent(bound: Int)
      extends RuntimeException(s"fee did not converge in $bound passes")

  val refundHandler: DiffHandler = (diff: Value, candidate: Transaction) =>
    // Production code replaces the designated refund output using diff, then returns the candidate.
    Right(candidate)

  def balance(
      initial: Transaction,
      bound: Int,
      balanceOnce: (Transaction, DiffHandler) => Either[TxBalancingError, Transaction]
  ): Either[Throwable, Transaction] =
    // Delayed redeemer and datum builders must run before min-UTxO and this balance loop.
    def loop(previous: Transaction, pass: Int): Either[Throwable, Transaction] =
      if pass > bound then Left(NonConvergent(bound))
      else
        // balanceOnce must allocate a fresh builder while retaining the pinned fixture UTxOs.
        balanceOnce(previous, refundHandler) match
          case Left(error)                         => Left(RuntimeException(error.toString))
          case Right(candidate) if candidate == previous => Right(candidate)
          case Right(candidate)                    => loop(candidate, pass + 1)
    loop(initial, 1)
