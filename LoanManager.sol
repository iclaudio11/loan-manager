// SPDX-License-Identifier: MIT
pragma solidity >=0.6.12 <0.9.0;

library InterestCalculator {
    function calculateInterest(uint256 _amount, uint256 _interestRate, uint256 _duration) internal pure returns (uint256) {
        return (_amount * _interestRate * _duration) / 100;
    }

    function calculatePenalty(uint256 _amount, uint256 _dueDate, uint256 _paidDate) internal pure returns (uint256) {
        if (_paidDate > _dueDate) {
            uint256 daysLate = (_paidDate - _dueDate) / 1 days;
            uint256 penaltyPercentage = 5; 
            return (_amount * penaltyPercentage * daysLate) / 100;
        }
        return 0;
    }
}

contract LoanManager {
    using InterestCalculator for *;

    address public lender;
    address public borrower;
    uint256 public amount;
    uint256 public interestRate;
    uint256 public duration;
    uint256 public startDate;
    uint256 public endDate;
    uint256 public totalRepayment;

    enum LoanStatus { Active, Repaid, Defaulted, Canceled }
    LoanStatus public loanStatus;

    struct LoanState {
        LoanStatus status;
        uint256 timestamp;
    }

    LoanState public loanState;

    event LoanCreated(address indexed _lender, address indexed _borrower, uint256 _amount, uint256 _interestRate, uint256 _duration);
    event LoanRepaid(address indexed _borrower, uint256 _repaymentAmount);

    modifier onlyLender() {
        require(msg.sender == lender, "Only the lender can call this function");
        _;
    }

    modifier onlyBorrower() {
        require(msg.sender == borrower, "Only the borrower can call this function");
        _;
    }

    modifier onlyActiveLoan() {
        require(loanState.status == LoanStatus.Active, "Loan must be active");
        _;
    }

    function createLoan(address _borrower, uint256 _amount, uint256 _interestRate, uint256 _duration) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(_interestRate > 0, "Interest rate must be greater than zero");
        require(_duration > 0, "Duration must be greater than zero");

        lender = msg.sender;
        borrower = _borrower;
        amount = _amount;
        interestRate = _interestRate;
        duration = _duration;
        startDate = block.timestamp;
        endDate = startDate + _duration;
        totalRepayment = _calculateTotalRepayment();

        loanState = LoanState({
            status: LoanStatus.Active,
            timestamp: block.timestamp
        });

        emit LoanCreated(lender, borrower, amount, interestRate, duration);
    }

    function repayLoan() external onlyBorrower onlyActiveLoan {
        require(block.timestamp <= endDate, "Loan is already overdue");

        uint256 penalty = _calculatePenalty();
        uint256 repaymentAmount = totalRepayment + penalty;

        require(msg.sender.balance >= repaymentAmount, "Insufficient funds to repay the loan");

        payable(lender).transfer(repaymentAmount);

        loanState.status = LoanStatus.Repaid;

        emit LoanRepaid(borrower, repaymentAmount);
    }

    function _calculateTotalRepayment() internal view returns (uint256) {
        uint256 interest = InterestCalculator.calculateInterest(amount, interestRate, duration);
        return amount + interest;
    }

    function _calculatePenalty() internal view returns (uint256) {
        return InterestCalculator.calculatePenalty(amount, endDate, block.timestamp);
    }
}
