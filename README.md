# Stablecoin AMM Demo (Sepolia)

This project demonstrates a **testnet-only stablecoin mechanism** using:

- ERC20 stablecoin with controlled mint/burn
- Custom constant-product AMM (x*y=k)
- Chainlink ETH/USD oracle integration
- Automated peg adjustment logic

## ⚠️ Disclaimer

This project is **for educational and demonstration purposes only**.
It does **not** represent a production-ready stablecoin.

## Architecture

- `DemoStablecoin.sol` – ERC20 with AMM-controlled supply
- `SimpleAMMWithPeg.sol` – AMM + oracle-based peg logic
- `MockOracle.sol` – Local testing oracle
- Foundry deployment & tests

## Key Concepts Demonstrated

- Oracle-referenced pricing
- AMM mechanics
- Supply-based peg stabilization
- Separation of concerns
- Solidity project structure

## Deployment

```bash
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC --broadcast
