package theater.nonoop;

public class AccountService {

    public void deposit(Account account, double amountToDeposit) {
        account.setAmount(account.getAmount() + amountToDeposit);
    }

    public void withdraw(Account account, double amountToWithDraw) {
        if (account.getAmount() < amountToWithDraw) {
            throw new IllegalArgumentException("Not enough money");
        }
        account.setAmount(account.getAmount() - amountToWithDraw);
    }

    public void transfer(Account fromAccount, Account toAccount, double amount) {
        deposit(toAccount, amount);
        withdraw(fromAccount, amount);
    }
}
