package theater.oop;

public class Account {

    private double amount;

    public void Account(double amount) {
        if (amount < 0) {
            throw new IllegalArgumentException("Account amount cannot be negative");
        }
        this.amount = amount;
    }

    public void withDraw(double amountToWithdraw) {
        if (amount < amountToWithdraw) {
            throw new IllegalArgumentException("Not enough money");
        }
        this.amount = amountToWithdraw;
    }

    public void deposit(double amountToDeposit) {
        if (amountToDeposit < 0) {
            throw new IllegalArgumentException("Illegal deposit");
        }
        this.amount += amountToDeposit;
    }

    public void transferFunds(Account toAccount, double amountToTransfer) {
        double originalAmount = amount;
        withDraw(amountToTransfer);
        try {
            toAccount.deposit(amountToTransfer);
        } catch (Exception e) {
            amount = originalAmount;
            throw e;
        }
    }
}
