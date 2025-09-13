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
- **🎯 Goal-Based Savings**: Create and track multiple savings goals with progress monitoring

## 🏗️ Contract Details

### Default Settings
- **Base Interest Rate**: 5% (0.05% per block)
- **Minimum Deposit**: 1 STX (1,000,000 microSTX)
- **Lock Period**: 144 blocks (~24 hours)
- **Transaction History**: Last 50 transactions per user

### 🎯 Tiered Interest Rates
**Balance-Based Tiers:**
- **Tier 0**: 0+ STX → 5% APY (base rate)
- **Tier 1**: 5+ STX → 7% APY 
- **Tier 2**: 10+ STX → 10% APY
- **Tier 3**: 50+ STX → 15% APY
- **Tier 4**: 100+ STX → 20% APY

**Time-Based Bonuses:**
- **0-9 days**: 100% (no bonus)
- **10-29 days**: 110% bonus multiplier
- **30-99 days**: 125% bonus multiplier
- **100+ days**: 150% bonus multiplier

### Interest Calculation
The contract uses tiered compound interest calculated per block:
- Interest compounds every 144 blocks
- **Tiered Rate** = Base Tier Rate × Time Bonus Multiplier
- Formula: `compound_interest = principal * tiered_rate * periods`
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

#### Check Your Interest Tier
```clarity
(contract-call? .savings-account-with-interest get-user-tier tx-sender)
```

#### Check Time Bonus Tier
```clarity
(contract-call? .savings-account-with-interest get-time-bonus-tier tx-sender)
```

#### Calculate Your Tiered Rate
```clarity
(contract-call? .savings-account-with-interest calculate-tiered-rate tx-sender)
```

### 🎯 Goal Management Functions

#### Create Savings Goal
```clarity
(contract-call? .savings-account-with-interest create-goal "Emergency Fund" u50000000 u172800 u1)
```

#### Allocate Funds to Goal
```clarity
(contract-call? .savings-account-with-interest allocate-to-goal u0 u10000000)
```

#### Check Goal Progress
```clarity
(contract-call? .savings-account-with-interest get-goal-progress tx-sender u0)
```

#### View Your Goals
```clarity
(contract-call? .savings-account-with-interest get-user-goal tx-sender u0)
```

#### Update Goal Details
```clarity
(contract-call? .savings-account-with-interest update-goal u0 u75000000 u259200 u2)
```

#### Remove Funds from Goal
```clarity
(contract-call? .savings-account-with-interest deallocate-from-goal u0 u5000000)
```

#### Delete Completed Goal
```clarity
(contract-call? .savings-account-with-interest delete-goal u0)
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

#### Initialize Tier System
```clarity
(contract-call? .savings-account-with-interest initialize-tiers)
```

#### Set Custom Balance Tier
```clarity
(contract-call? .savings-account-with-interest set-balance-tier u5 u200000000 u25)
```

#### Set Custom Time Bonus
```clarity
(contract-call? .savings-account-with-interest set-time-bonus u4 u28800 u200)
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
7. **Goal-oriented financial planning** and progress tracking
8. **Fund allocation** and resource management

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
- `u106`: Goal not found
- `u107`: Goal limit reached (max 10 goals)
- `u108`: Invalid allocation amount

## 🎨 Example Workflow

1. **🏦 Open Account**: Make your first deposit (minimum 1 STX)
2. **🎯 Set Goals**: Create savings goals like "Emergency Fund" or "Vacation"
3. **💰 Allocate**: Assign portions of your balance toward specific goals
4. **⏰ Wait**: Let time pass for interest to accumulate
5. **📈 Track**: Monitor goal progress and interest growth
6. **💸 Achieve**: Complete goals and withdraw funds + interest
7. **🔄 Repeat**: Create new goals and continue building wealth

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
