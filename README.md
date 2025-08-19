# ZeroLiquid

> **Zero-liquidation DeFi lending protocol with innovative collateral management**

ZeroLiquid is a revolutionary DeFi lending smart contract built on the Stacks blockchain that implements zero-liquidation lending through dynamic collateral rebalancing and automated risk management. The protocol ensures borrowers never face liquidation by proactively managing collateral ratios and enabling automated rebalancing mechanisms.

## 🚀 Features

- **Zero-Liquidation Lending**: Innovative mechanism that prevents traditional liquidations through automated collateral management
- **Dynamic Collateral Rebalancing**: Automated systems to maintain healthy collateral ratios
- **SIP-010 Token Support**: Compatible with all standard fungible tokens on Stacks
- **Automated Risk Management**: Intelligent monitoring and adjustment of loan positions
- **Emergency Safeguards**: Built-in emergency shutdown mechanisms for protocol security
- **Transparent Interest Calculation**: Simple interest model with clear accrual tracking
- **Bot Authorization System**: Automated rebalancing through authorized bot networks

## 📋 Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Version**: 1.0.0
- **Clarity Version**: 2
- **Epoch**: 2.5
- **Minimum Collateral Ratio**: 150%
- **Target Collateral Ratio**: 200%
- **Liquidation Threshold**: 130% (never reached due to zero-liquidation mechanism)
- **Default Interest Rate**: 5% annual

## 🛠️ Installation

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) (latest version)
- [Node.js](https://nodejs.org/) (v16+ recommended)
- [Git](https://git-scm.com/)

### Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ZeroLiquid
   ```

2. **Navigate to contract directory**
   ```bash
   cd ZeroLiquid_contract
   ```

3. **Install dependencies**
   ```bash
   npm install
   ```

4. **Check contract syntax**
   ```bash
   clarinet check
   ```

5. **Run tests**
   ```bash
   npm test
   ```

## 💡 Usage Examples

### Basic Operations

#### 1. Initialize the Protocol
```clarity
;; Owner must initialize the protocol first
(contract-call? .ZeroLiquid initialize)
```

#### 2. Deposit Collateral
```clarity
;; Deposit 1000 tokens as collateral
(contract-call? .ZeroLiquid deposit-collateral u1000000 .your-token-contract)
```

#### 3. Borrow Against Collateral
```clarity
;; Borrow 500 tokens against deposited collateral
(contract-call? .ZeroLiquid borrow u500000 .collateral-token-contract)
```

#### 4. Repay Loan
```clarity
;; Repay 100 tokens towards loan
(contract-call? .ZeroLiquid repay u100000)
```

#### 5. Rebalance Collateral
```clarity
;; Add additional collateral to maintain healthy ratio
(contract-call? .ZeroLiquid rebalance-collateral 
  'SP1ABC...borrower-address 
  u200000 
  .collateral-token-contract)
```

### Read-Only Functions

#### Check Loan Information
```clarity
;; Get complete loan details for a borrower
(contract-call? .ZeroLiquid get-loan-info 'SP1ABC...borrower-address)
```

#### Check Collateral Balance
```clarity
;; Get user's collateral balance
(contract-call? .ZeroLiquid get-collateral-balance 'SP1ABC...user-address)
```

#### Calculate Collateral Ratio
```clarity
;; Calculate ratio for given collateral and loan amounts
(contract-call? .ZeroLiquid calculate-collateral-ratio u1000000 u500000)
;; Returns: u2000000 (200% ratio)
```

#### Check Loan Health
```clarity
;; Verify if loan is above minimum collateral ratio
(contract-call? .ZeroLiquid is-loan-healthy 'SP1ABC...borrower-address)
```

## 📚 Contract Functions Documentation

### Public Functions

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `initialize` | Initialize protocol (owner only) | None | `(response bool uint)` |
| `deposit-collateral` | Deposit tokens as collateral | `amount`, `token` | `(response uint uint)` |
| `borrow` | Borrow against collateral | `loan-amount`, `collateral-token` | `(response uint uint)` |
| `repay` | Repay loan amount | `repay-amount` | `(response uint uint)` |
| `rebalance-collateral` | Add collateral to maintain ratios | `borrower`, `additional-collateral`, `token` | `(response bool uint)` |
| `authorize-bot` | Authorize rebalancing bot (owner only) | `bot` | `(response bool uint)` |
| `set-emergency-shutdown` | Emergency protocol halt (owner only) | None | `(response bool uint)` |

### Read-Only Functions

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `get-loan-info` | Retrieve loan details | `borrower` | `(optional loan-info)` |
| `get-collateral-balance` | Get user's collateral balance | `user` | `uint` |
| `calculate-collateral-ratio` | Calculate collateral ratio | `collateral-amount`, `loan-amount` | `uint` |
| `is-loan-healthy` | Check if loan meets minimum ratio | `borrower` | `bool` |
| `get-protocol-stats` | Get protocol statistics | None | `protocol-stats` |
| `calculate-interest` | Calculate accrued interest | `borrower` | `uint` |
| `needs-rebalancing` | Check if rebalancing needed | `borrower` | `bool` |

### Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `err-owner-only` | Function restricted to contract owner |
| u101 | `err-insufficient-balance` | Insufficient token balance |
| u102 | `err-insufficient-collateral` | Collateral below minimum ratio |
| u103 | `err-loan-not-found` | No active loan found for user |
| u104 | `err-already-exists` | User already has active loan |
| u105 | `err-invalid-amount` | Invalid amount provided |
| u106 | `err-loan-not-active` | Loan is not active |
| u107 | `err-unauthorized` | Unauthorized access |
| u108 | `err-invalid-collateral-ratio` | Invalid collateral ratio |

## 🚀 Deployment Guide

### Local Development Network (Devnet)

1. **Start Clarinet console**
   ```bash
   clarinet console
   ```

2. **Deploy contract**
   ```clarity
   ::deploy_contracts
   ```

3. **Initialize protocol**
   ```clarity
   (contract-call? .ZeroLiquid initialize)
   ```

### Testnet Deployment

1. **Configure network settings**
   ```bash
   # Edit settings/Testnet.toml
   # Add your testnet configuration
   ```

2. **Deploy to testnet**
   ```bash
   clarinet deployments generate --testnet
   clarinet deployments apply -p deployments/default.testnet-plan.yaml
   ```

### Mainnet Deployment

⚠️ **Warning**: Ensure thorough testing before mainnet deployment

1. **Configure mainnet settings**
   ```bash
   # Edit settings/Mainnet.toml
   # Add production configuration
   ```

2. **Generate deployment plan**
   ```bash
   clarinet deployments generate --mainnet
   ```

3. **Review and apply**
   ```bash
   # Carefully review the generated plan
   clarinet deployments apply -p deployments/default.mainnet-plan.yaml
   ```

## 🛡️ Security Notes

### Important Considerations

- **Owner Privileges**: Contract owner has significant control including emergency shutdown
- **Bot Authorization**: Only authorized bots can trigger rebalancing for other users
- **Interest Calculation**: Uses simple interest model based on block height
- **Emergency Mechanisms**: Built-in emergency shutdown for critical situations
- **Collateral Management**: Automated systems prevent liquidation through proactive rebalancing

### Best Practices

1. **Always test thoroughly** on devnet and testnet before mainnet deployment
2. **Monitor collateral ratios** regularly to ensure protocol health
3. **Authorize trusted bots** only for automated rebalancing
4. **Implement proper access controls** for administrative functions
5. **Regular security audits** recommended before production use

### Known Limitations

- Contract assumes sufficient STX balance for loan disbursement
- Simple interest model may need enhancement for complex scenarios
- Bot authorization is binary (authorized/not authorized)
- Emergency shutdown affects all protocol operations

## 📊 Protocol Ratios

- **Minimum Collateral Ratio**: 150% (1.5x overcollateralization)
- **Target Collateral Ratio**: 200% (2x overcollateralization for safety)
- **Liquidation Threshold**: 130% (theoretical - never reached due to zero-liquidation)
- **Protocol Fee**: 1% (configurable by owner)

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:report

# Watch for changes
npm run test:watch
```

## 📄 License

This project is licensed under the ISC License.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📞 Support

For questions or support, please open an issue in the repository.

---

**⚠️ Disclaimer**: This smart contract is provided as-is. Users should conduct their own security audits and due diligence before using in production environments. The developers assume no responsibility for any financial losses or damages.