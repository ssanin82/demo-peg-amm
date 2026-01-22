"""
Oracle bot that fetches ETH price from Binance and updates the oracle contract
"""
import time
import requests
from web3 import Web3
from config import RPC_URL, ORACLE_ADDRESS, LOG_FILE
from utils import log_message, check_kill_switch

def get_binance_price():
    """Fetch ETH/USDT price from Binance"""
    try:
        response = requests.get("https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT", timeout=5)
        data = response.json()
        price = float(data["price"])
        return int(price * 1e8)  # Convert to 8 decimals (Chainlink format)
    except Exception as e:
        log_message(f"Error fetching Binance price: {e}", "ERROR")
        return None

def update_oracle_price(w3: Web3, account, oracle_address: str, price: int):
    """Update oracle price on chain"""
    abi = [{"inputs": [{"internalType": "int256", "name": "_price", "type": "int256"}], "name": "setPrice", "outputs": [], "stateMutability": "nonpayable", "type": "function"}]
    contract = w3.eth.contract(address=oracle_address, abi=abi)
    
    tx = contract.functions.setPrice(price).build_transaction({
        "from": account.address,
        "nonce": w3.eth.get_transaction_count(account.address),
        "gas": 100000,
        "gasPrice": w3.eth.gas_price
    })
    
    signed_tx = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    
    log_message(f"Oracle price updated to ${price / 1e8:.2f} (tx: {tx_hash.hex()})")
    return receipt

def main():
    """Main oracle bot loop"""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        log_message("Failed to connect to RPC", "ERROR")
        return
    
    # Use a default account (you may need to set up a dedicated account)
    # For local Anvil, we can use the default account
    account = w3.eth.account.from_key("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")  # Anvil default
    
    log_message("Oracle bot started")
    
    # Initial price update
    price = get_binance_price()
    if price:
        update_oracle_price(w3, account, ORACLE_ADDRESS, price)
        log_message("Initial oracle price set")
    
    # Main loop
    while not check_kill_switch():
        try:
            price = get_binance_price()
            if price:
                update_oracle_price(w3, account, ORACLE_ADDRESS, price)
            time.sleep(5)  # Update every 5 seconds
        except Exception as e:
            log_message(f"Error in oracle bot loop: {e}", "ERROR")
            time.sleep(5)
    
    log_message("Oracle bot stopped")

if __name__ == "__main__":
    main()
