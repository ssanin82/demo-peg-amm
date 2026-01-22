"""
Utility functions for bots
"""
import json
import time
from datetime import datetime
from web3 import Web3
from config import LOG_FILE, STATS_FILE

def log_message(message: str, level: str = "INFO"):
    """Log a message to the log file"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}\n"
    with open(LOG_FILE, "a") as f:
        f.write(log_entry)
    print(log_entry.strip())

def log_statistics(event_type: str, data: dict):
    """Log statistics to the statistics file"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = {
        "timestamp": timestamp,
        "event_type": event_type,
        "data": data
    }
    with open(STATS_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")

def check_kill_switch():
    """Check if kill switch is activated"""
    try:
        with open(".kill_switch", "r") as f:
            return f.read().strip() == "1"
    except FileNotFoundError:
        return False

def format_wei(value: int, decimals: int = 18) -> float:
    """Convert wei to human-readable format"""
    return value / (10 ** decimals)

def format_ether(value: int) -> float:
    """Convert wei to ether"""
    return format_wei(value, 18)

def get_balance(w3: Web3, address: str, token_address: str = None) -> int:
    """Get balance of an address (native or ERC20)"""
    if token_address:
        # ERC20 balance
        abi = [{"constant": True, "inputs": [{"name": "_owner", "type": "address"}], "name": "balanceOf", "outputs": [{"name": "balance", "type": "uint256"}], "type": "function"}]
        contract = w3.eth.contract(address=token_address, abi=abi)
        return contract.functions.balanceOf(address).call()
    else:
        # Native balance
        return w3.eth.get_balance(address)

def log_wallet_balances(w3: Web3, wallet_address: str, wallet_name: str, 
                       mweth_address: str, dusd_address: str, dusc_address: str):
    """Log wallet balances for monitoring"""
    mweth_balance = get_balance(w3, wallet_address, mweth_address)
    dusd_balance = get_balance(w3, wallet_address, dusd_address)
    dusc_balance = get_balance(w3, wallet_address, dusc_address)
    
    log_message(f"{wallet_name} balances - mWETH: {format_ether(mweth_balance):.6f}, "
                f"dUSD: {format_ether(dusd_balance):.2f}, dUSC: {format_ether(dusc_balance):.2f}")
