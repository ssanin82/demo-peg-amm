"""
Configuration file for the ecosystem bots
"""
import os
from dotenv import load_dotenv

load_dotenv()

# RPC URL - defaults to local Anvil
RPC_URL = os.getenv("RPC_URL", "http://localhost:8545")

# Contract addresses (will be set after deployment)
MWETH_ADDRESS = os.getenv("MWETH_ADDRESS", "")
DUSD_ADDRESS = os.getenv("DUSD_ADDRESS", "")
DUSC_ADDRESS = os.getenv("DUSC_ADDRESS", "")
ORACLE_ADDRESS = os.getenv("ORACLE_ADDRESS", "")
DEX_ADDRESS = os.getenv("DEX_ADDRESS", "")
LENDING_ADDRESS = os.getenv("LENDING_ADDRESS", "")
MINTER_REDEEMER_ADDRESS = os.getenv("MINTER_REDEEMER_ADDRESS", "")

# Wallet private keys (for testing - in production use secure key management)
WALLET_1_KEY = os.getenv("WALLET_1_KEY", "")
WALLET_2_KEY = os.getenv("WALLET_2_KEY", "")
WALLET_3_KEY = os.getenv("WALLET_3_KEY", "")
WALLET_4_KEY = os.getenv("WALLET_4_KEY", "")

# Logging
LOG_FILE = os.getenv("LOG_FILE", "ecosystem.log")
STATS_FILE = os.getenv("STATS_FILE", "statistics.log")

# Bot control
KILL_SWITCH_FILE = os.getenv("KILL_SWITCH_FILE", ".kill_switch")
