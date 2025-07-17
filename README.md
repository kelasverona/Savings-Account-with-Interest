# 💰 Savings Account with Interest

A smart contract implementation on the Stacks blockchain that teaches **compounding rewards** through a savings account system. Users can deposit STX tokens, earn compound interest over time, and withdraw their funds with accumulated interest.

## 🌟 Features

- **💵 Secure Deposits**: Deposit STX tokens into your savings account
- **📈 Compound Interest**: Earn interest that compounds over time
- **🔒 Lock Period**: Time-locked deposits to maximize interest earnings
- **⚡ Interest Claims**: Claim accumulated interest without withdrawing principal
- **🚨 Emergency Withdrawal**: Access funds early with penalty
- **📊 Transaction History**: Track all deposits, withdrawals, and interest earned
- **👤 Account Management**: View account info and calculate potential earnings

## 🏗️ Contract Details

### Default Settings
- **Interest Rate**: 5% (0.05% per block)
- **Minimum Deposit**: 1 STX (1,000,000 microSTX)
- **Lock Period**: 144 blocks (~24 hours)
- **Transaction History**: Last 50 transactions per user

### Interest Calculation
The contract uses compound interest calculated per block:
- Interest compounds every 144 blocks
- Formula: `compound_interest = principal * (1 + rate/periods)^periods`
- Interest can be claimed without affecting principal balance

## 🚀 Usage

### 🔧 Deployment
```bash
clarinet deploy --devnet
```

### 📝 Core Functions

#### Deposit STX
```clarity
(contract-call? .savings-account-with-interest deposit u1000000)
```

#### Withdraw with Interest
```clarity
(contract-call? .savings-account-with-interest withdraw u500000)
```

#### Claim Interest Only
```clarity
(contract-call? .savings-account-with-interest claim-interest)
```

#### Emergency Withdrawal (10% penalty)
```clarity
(contract-call? .savings-account-with-interest emergency-withdraw)
```

### 📊 Read-Only Functions

#### Get Account Information
```clarity
(contract-call? .savings-account-with-interest get-account-info tx-sender)
```

#### Calculate Current Interest
```clarity
(contract-call? .savings-account-with-interest calculate-compound-interest tx-sender)
```

#### Get Total Balance (Principal + Interest)
```clarity
(contract-call? .savings-account-with-interest get-total-balance tx-sender)
```

#### Check Time Until Unlock
```clarity
(contract-call? .savings-account-with-interest time-until-unlock tx-sender)
```

#### View Transaction History
```clarity
(contract-call? .savings-account-with-interest get-user-transactions tx-sender)
```

### 🛠️ Admin Functions (Contract Owner Only)

#### Set Interest Rate
```clarity
(contract-call? .savings-account-with-interest set-interest-rate u10)
```

#### Set Minimum Deposit
```clarity
(contract-call? .savings-account-with-interest set-minimum-deposit u2000000)
```

#### Set Lock Period
```clarity
(contract-call? .savings-account-with-interest set-lock-period u288)
```

#### Toggle Contract Active/Inactive
```clarity
(contract-call? .savings-account-with-interest toggle-contract true)
```

## 📋 Testing

Run the test suite:
```bash
clarinet test
```

## 🎯 Learning Objectives

This contract teaches:
1. **Time-based calculations** in smart contracts
2. **Compound interest** mathematics
3. **State management** for user accounts
4. **Access control** patterns
5. **Error handling** in Clarity
6. **Event tracking** through transaction history

## 🔐 Security Features

- **Owner-only admin functions** for contract management
- **Input validation** for all public functions
- **Balance checks** before withdrawals
- **Lock period enforcement** to prevent premature withdrawals
- **Emergency withdrawal** with penalty system

## 📊 Error Codes

- `u100`: Unauthorized access
- `u101`: Insufficient balance
- `u102`: Invalid amount
- `u103`: Account not found
- `u104`: Withdrawal too early
- `u105`: Invalid interest rate

## 🎨 Example Workflow

1. **🏦 Open Account**: Make your first deposit (minimum 1 STX)
2. **⏰ Wait**: Let time pass for interest to accumulate
3. **💰 Earn**: Interest compounds automatically every 144 blocks
4. **📈 Check**: Monitor your growing balance
5. **💸 Withdraw**: Access your funds + interest after lock period
6. **🔄 Repeat**: Continue the cycle to maximize compound returns

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
