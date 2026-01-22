# Demo Peg AMM Ecosystem

A comprehensive blockchain ecosystem simulation demonstrating stablecoin creation and maintenance with multiple components including smart contracts and Python bots.

## Overview

This ecosystem includes:
- **2 Stablecoins**: dUSD and dUSC
- **Mock mWETH Token**: Mock Wrapped ETH for testing
- **Simple DEX**: Two AMM pools (dUSD/mWETH and dUSC/mWETH)
- **Price Oracle**: Externally triggered oracle for ETH price
- **Lending Protocol**: Simplified AAVE-like lending with liquidation
- **Minter/Redeemer**: Mint and redeem stablecoins at $1 oracle price

## Components

### Smart Contracts

1. **DemoStablecoin.sol** - dUSD stablecoin
2. **DemoStablecoinUSC.sol** - dUSC stablecoin
3. **MockWETH.sol** - Mock Wrapped ETH token
4. **MockOracle.sol** - Price oracle contract
5. **SimpleDEX.sol** - DEX with two AMM pools
6. **LendingProtocol.sol** - Lending protocol with 150% collateralization and liquidation
7. **MinterRedeemer.sol** - Mint/redeem stablecoins at $1

### Python Bots

1. **oracle_bot.py** - Fetches ETH price from Binance and updates oracle every 5 seconds
2. **retailer_bot_1.py** - Trades mWETH in dUSD/mWETH pool (wallet 1)
3. **retailer_bot_2.py** - Trades mWETH in dUSC/mWETH pool (wallet 2)
4. **profit_bot_1.py** - Arbitrage and liquidation bot (wallet 3, monitors wallet 4)
5. **profit_bot_2.py** - Arbitrage and liquidation bot (wallet 4, monitors wallet 3)

## Setup

### Prerequisites

- Foundry (forge, anvil)
- Python 3.8+
- Node.js (for some tooling)

### Installation

1. Install Foundry dependencies:
```bash
forge install
```

2. Install Python dependencies:
```bash
cd bots
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cd ..
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Deployment

### Deploy Contracts

```bash
# Start Anvil (local blockchain)
anvil

# In another terminal, deploy contracts
forge script script/DeployEcosystem.s.sol:DeployEcosystem --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

After deployment, update your `.env` file with the contract addresses from the deployment output.

### Set Wallet Private Keys

The deploy script creates wallets 1-4. You need to set their private keys in `.env`:

```bash
# Generate or use existing private keys for wallets 1-4
WALLET_1_KEY=your_private_key_1
WALLET_2_KEY=your_private_key_2
WALLET_3_KEY=your_private_key_3
WALLET_4_KEY=your_private_key_4
```

## Running the Ecosystem

### Start Everything

```bash
./run_ecosystem.sh
```

This script will:
1. Start Anvil (if not running)
2. Deploy all contracts
3. Start all Python bots

### Stop Everything

```bash
./stop_ecosystem.sh
```

This activates the kill switch and stops all bots and Anvil.

## Monitoring

### Logs

- `ecosystem.log` - General ecosystem logs
- `statistics.log` - Transaction statistics (JSON format)
- `oracle_bot.log` - Oracle bot logs
- `retailer_bot_1.log` - Retailer bot 1 logs
- `retailer_bot_2.log` - Retailer bot 2 logs
- `profit_bot_1.log` - Profit bot 1 logs
- `profit_bot_2.log` - Profit bot 2 logs

### Statistics

The `statistics.log` file contains chronological records of:
- All lending operations (borrow, repay, liquidation)
- All AMM transactions
- All mint and burn operations for dUSD, dUSC, and mWETH

## Testing

Run the test suite:

```bash
forge test
```

## Architecture

### Initial State

After deployment:
- **DEX**: 6000 dUSD, 6000 dUSC, 4 mWETH (2 mWETH in each pool)
- **Lending Protocol**: 10000 dUSD, 10000 dUSC in reserves
- **Wallet 1**: 2000 dUSD
- **Wallet 2**: 2000 dUSC
- **Wallet 3**: 1 mWETH
- **Wallet 4**: 1 mWETH

### Bot Behavior

- **Oracle Bot**: Updates price every 5 seconds from Binance
- **Retailer Bots**: Trade randomly between 0.01-0.3 mWETH, maximizing profit
- **Profit Bots**: Monitor for arbitrage opportunities and liquidation chances

## License

MIT
