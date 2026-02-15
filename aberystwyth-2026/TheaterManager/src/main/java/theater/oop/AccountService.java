package theater.oop;

public class AccountService {

    public void deposit(Account account, double amountToDeposit) {
        account.deposit(amountToDeposit);
    }

    public void withdraw(Account account, double amountToWithDraw) {
        account.withDraw(amountToWithDraw);
    }

    public void transfer(Account fromAccount, Account toAccount, double amount) {
        fromAccount.transferFunds(toAccount, amount);
    }
}
