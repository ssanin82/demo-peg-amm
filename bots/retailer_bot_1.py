"""
Retailer bot 1 - trades mWETH in dUSD/mWETH pool
"""
import time
import random
from web3 import Web3
from config import RPC_URL, DEX_ADDRESS, DUSD_ADDRESS, MWETH_ADDRESS, WALLET_1_KEY, ORACLE_ADDRESS
from utils import log_message, check_kill_switch, log_statistics, log_wallet_balances, format_ether, get_balance

def get_oracle_price(w3: Web3, oracle_address: str) -> float:
    """Get current ETH price from oracle"""
    abi = [{"inputs": [], "name": "latestRoundData", "outputs": [{"name": "", "type": "uint80"}, {"name": "", "type": "int256"}, {"name": "", "type": "uint256"}, {"name": "", "type": "uint256"}, {"name": "", "type": "uint80"}], "stateMutability": "view", "type": "function"}]
    contract = w3.eth.contract(address=oracle_address, abi=abi)
    _, price, _, _, _ = contract.functions.latestRoundData().call()
    return float(price) / 1e8

def get_pool_price(w3: Web3, dex_address: str) -> float:
    """Get current pool price (dUSD per mWETH)"""
    abi = [{"inputs": [], "name": "getDUSDPrice", "outputs": [{"name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"}]
    contract = w3.eth.contract(address=dex_address, abi=abi)
    price = contract.functions.getDUSDPrice().call()
    return float(price) / 1e18

def calculate_profit(w3: Web3, wallet_address: str, oracle_price: float) -> float:
    """Calculate current profit"""
    dusd_balance = get_balance(w3, wallet_address, DUSD_ADDRESS)
    mweth_balance = get_balance(w3, wallet_address, MWETH_ADDRESS)
    return format_ether(dusd_balance) + format_ether(mweth_balance) * oracle_price

def try_buy_mweth(w3: Web3, account, dex_address: str, amount_dusd: int) -> bool:
    """Try to buy mWETH with dUSD"""
    try:
        abi = [{"inputs": [{"name": "dusdIn", "type": "uint256"}], "name": "swapDUSDForWETH", "outputs": [{"name": "wethOut", "type": "uint256"}], "stateMutability": "nonpayable", "type": "function"}]
        contract = w3.eth.contract(address=dex_address, abi=abi)
        
        # Approve if needed
        approve_abi = [{"inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}], "name": "approve", "outputs": [{"name": "", "type": "bool"}], "stateMutability": "nonpayable", "type": "function"}]
        token_contract = w3.eth.contract(address=DUSD_ADDRESS, abi=approve_abi)
        token_contract.functions.approve(dex_address, amount_dusd).transact({
            "from": account.address,
            "gas": 100000,
            "gasPrice": w3.eth.gas_price
        })
        
        tx = contract.functions.swapDUSDForWETH(amount_dusd).build_transaction({
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": 200000,
            "gasPrice": w3.eth.gas_price
        })
        
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        log_message(f"Bought mWETH with {format_ether(amount_dusd):.2f} dUSD (tx: {tx_hash.hex()})")
        log_statistics("AMM_TRANSACTION", {
            "type": "buy",
            "pool": "dUSD/mWETH",
            "amount_dusd": str(amount_dusd),
            "tx_hash": tx_hash.hex()
        })
        return True
    except Exception as e:
        log_message(f"Failed to buy mWETH: {e}", "ERROR")
        return False

def try_sell_mweth(w3: Web3, account, dex_address: str, amount_mweth: int) -> bool:
    """Try to sell mWETH for dUSD"""
    try:
        abi = [{"inputs": [{"name": "wethIn", "type": "uint256"}], "name": "swapWETHForDUSD", "outputs": [{"name": "dusdOut", "type": "uint256"}], "stateMutability": "nonpayable", "type": "function"}]
        contract = w3.eth.contract(address=dex_address, abi=abi)
        
        # Approve if needed
        approve_abi = [{"inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}], "name": "approve", "outputs": [{"name": "", "type": "bool"}], "stateMutability": "nonpayable", "type": "function"}]
        token_contract = w3.eth.contract(address=MWETH_ADDRESS, abi=approve_abi)
        token_contract.functions.approve(dex_address, amount_mweth).transact({
            "from": account.address,
            "gas": 100000,
            "gasPrice": w3.eth.gas_price
        })
        
        tx = contract.functions.swapWETHForDUSD(amount_mweth).build_transaction({
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": 200000,
            "gasPrice": w3.eth.gas_price
        })
        
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        log_message(f"Sold {format_ether(amount_mweth):.6f} mWETH for dUSD (tx: {tx_hash.hex()})")
        log_statistics("AMM_TRANSACTION", {
            "type": "sell",
            "pool": "dUSD/mWETH",
            "amount_mweth": str(amount_mweth),
            "tx_hash": tx_hash.hex()
        })
        return True
    except Exception as e:
        log_message(f"Failed to sell mWETH: {e}", "ERROR")
        return False

def main():
    """Main retailer bot 1 loop"""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        log_message("Failed to connect to RPC", "ERROR")
        return
    
    if not WALLET_1_KEY:
        log_message("WALLET_1_KEY not set", "ERROR")
        return
    
    account = w3.eth.account.from_key(WALLET_1_KEY)
    log_message(f"Retailer bot 1 started (wallet: {account.address})")
    
    while not check_kill_switch():
        try:
            oracle_price = get_oracle_price(w3, ORACLE_ADDRESS)
            pool_price = get_pool_price(w3, DEX_ADDRESS)
            profit = calculate_profit(w3, account.address, oracle_price)
            
            dusd_balance = get_balance(w3, account.address, DUSD_ADDRESS)
            mweth_balance = get_balance(w3, account.address, MWETH_ADDRESS)
            
            log_wallet_balances(w3, account.address, "Retailer Bot 1", 
                              MWETH_ADDRESS, DUSD_ADDRESS, "")
            log_message(f"Profit: ${profit:.2f}, Oracle: ${oracle_price:.2f}, Pool: {pool_price:.6f}")
            
            # Random amount between 0.01 and 0.3 mWETH
            amount_mweth = random.randint(1e16, 3e17)  # 0.01 to 0.3 ETH in wei
            amount_dusd = int(amount_mweth * pool_price)
            
            # Strategy: try to maximize profit
            # If pool price is lower than oracle, buy mWETH
            # If pool price is higher than oracle, sell mWETH
            # If can't buy, try to sell
            # If can't sell, decrease amount and try again
            
            if pool_price < oracle_price * 1e18 and dusd_balance >= amount_dusd:
                # Buy mWETH
                if not try_buy_mweth(w3, account, DEX_ADDRESS, amount_dusd):
                    # If buy fails, try to sell
                    if mweth_balance >= amount_mweth:
                        try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth)
                    else:
                        # Decrease amount
                        amount_mweth = mweth_balance // 2
                        if amount_mweth > 0:
                            try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth)
            elif mweth_balance >= amount_mweth:
                # Sell mWETH
                if not try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth):
                    # If sell fails, decrease amount
                    amount_mweth = mweth_balance // 2
                    if amount_mweth > 0:
                        try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth)
            elif dusd_balance >= amount_dusd:
                # Can't sell, try to buy
                try_buy_mweth(w3, account, DEX_ADDRESS, amount_dusd)
            
            time.sleep(10)  # Wait 10 seconds between trades
        except Exception as e:
            log_message(f"Error in retailer bot 1 loop: {e}", "ERROR")
            time.sleep(10)
    
    log_message("Retailer bot 1 stopped")

if __name__ == "__main__":
    main()
