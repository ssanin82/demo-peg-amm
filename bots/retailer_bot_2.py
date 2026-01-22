"""
Retailer bot 2 - trades mWETH in dUSC/mWETH pool
"""
import time
import random
from web3 import Web3
from config import RPC_URL, DEX_ADDRESS, DUSC_ADDRESS, MWETH_ADDRESS, WALLET_2_KEY, ORACLE_ADDRESS
from utils import log_message, check_kill_switch, log_statistics, log_wallet_balances, format_ether, get_balance

def get_oracle_price(w3: Web3, oracle_address: str) -> float:
    """Get current ETH price from oracle"""
    abi = [{"inputs": [], "name": "latestRoundData", "outputs": [{"name": "", "type": "uint80"}, {"name": "", "type": "int256"}, {"name": "", "type": "uint256"}, {"name": "", "type": "uint256"}, {"name": "", "type": "uint80"}], "stateMutability": "view", "type": "function"}]
    contract = w3.eth.contract(address=oracle_address, abi=abi)
    _, price, _, _, _ = contract.functions.latestRoundData().call()
    return float(price) / 1e8

def get_pool_price(w3: Web3, dex_address: str) -> float:
    """Get current pool price (dUSC per mWETH)"""
    abi = [{"inputs": [], "name": "getDUSCPrice", "outputs": [{"name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"}]
    contract = w3.eth.contract(address=dex_address, abi=abi)
    price = contract.functions.getDUSCPrice().call()
    return float(price) / 1e18

def calculate_profit(w3: Web3, wallet_address: str, oracle_price: float) -> float:
    """Calculate current profit"""
    dusc_balance = get_balance(w3, wallet_address, DUSC_ADDRESS)
    mweth_balance = get_balance(w3, wallet_address, MWETH_ADDRESS)
    return format_ether(dusc_balance) + format_ether(mweth_balance) * oracle_price

def try_buy_mweth(w3: Web3, account, dex_address: str, amount_dusc: int) -> bool:
    """Try to buy mWETH with dUSC"""
    try:
        abi = [{"inputs": [{"name": "duscIn", "type": "uint256"}], "name": "swapDUSCForWETH", "outputs": [{"name": "wethOut", "type": "uint256"}], "stateMutability": "nonpayable", "type": "function"}]
        contract = w3.eth.contract(address=dex_address, abi=abi)
        
        approve_abi = [{"inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}], "name": "approve", "outputs": [{"name": "", "type": "bool"}], "stateMutability": "nonpayable", "type": "function"}]
        token_contract = w3.eth.contract(address=DUSC_ADDRESS, abi=approve_abi)
        token_contract.functions.approve(dex_address, amount_dusc).transact({
            "from": account.address,
            "gas": 100000,
            "gasPrice": w3.eth.gas_price
        })
        
        tx = contract.functions.swapDUSCForWETH(amount_dusc).build_transaction({
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": 200000,
            "gasPrice": w3.eth.gas_price
        })
        
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        log_message(f"Bought mWETH with {format_ether(amount_dusc):.2f} dUSC (tx: {tx_hash.hex()})")
        log_statistics("AMM_TRANSACTION", {
            "type": "buy",
            "pool": "dUSC/mWETH",
            "amount_dusc": str(amount_dusc),
            "tx_hash": tx_hash.hex()
        })
        return True
    except Exception as e:
        log_message(f"Failed to buy mWETH: {e}", "ERROR")
        return False

def try_sell_mweth(w3: Web3, account, dex_address: str, amount_mweth: int) -> bool:
    """Try to sell mWETH for dUSC"""
    try:
        abi = [{"inputs": [{"name": "wethIn", "type": "uint256"}], "name": "swapWETHForDUSC", "outputs": [{"name": "duscOut", "type": "uint256"}], "stateMutability": "nonpayable", "type": "function"}]
        contract = w3.eth.contract(address=dex_address, abi=abi)
        
        approve_abi = [{"inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}], "name": "approve", "outputs": [{"name": "", "type": "bool"}], "stateMutability": "nonpayable", "type": "function"}]
        token_contract = w3.eth.contract(address=MWETH_ADDRESS, abi=approve_abi)
        token_contract.functions.approve(dex_address, amount_mweth).transact({
            "from": account.address,
            "gas": 100000,
            "gasPrice": w3.eth.gas_price
        })
        
        tx = contract.functions.swapWETHForDUSC(amount_mweth).build_transaction({
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": 200000,
            "gasPrice": w3.eth.gas_price
        })
        
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        log_message(f"Sold {format_ether(amount_mweth):.6f} mWETH for dUSC (tx: {tx_hash.hex()})")
        log_statistics("AMM_TRANSACTION", {
            "type": "sell",
            "pool": "dUSC/mWETH",
            "amount_mweth": str(amount_mweth),
            "tx_hash": tx_hash.hex()
        })
        return True
    except Exception as e:
        log_message(f"Failed to sell mWETH: {e}", "ERROR")
        return False

def main():
    """Main retailer bot 2 loop"""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        log_message("Failed to connect to RPC", "ERROR")
        return
    
    if not WALLET_2_KEY:
        log_message("WALLET_2_KEY not set", "ERROR")
        return
    
    account = w3.eth.account.from_key(WALLET_2_KEY)
    log_message(f"Retailer bot 2 started (wallet: {account.address})")
    
    while not check_kill_switch():
        try:
            oracle_price = get_oracle_price(w3, ORACLE_ADDRESS)
            pool_price = get_pool_price(w3, DEX_ADDRESS)
            profit = calculate_profit(w3, account.address, oracle_price)
            
            dusc_balance = get_balance(w3, account.address, DUSC_ADDRESS)
            mweth_balance = get_balance(w3, account.address, MWETH_ADDRESS)
            
            log_wallet_balances(w3, account.address, "Retailer Bot 2", 
                              MWETH_ADDRESS, "", DUSC_ADDRESS)
            log_message(f"Profit: ${profit:.2f}, Oracle: ${oracle_price:.2f}, Pool: {pool_price:.6f}")
            
            amount_mweth = random.randint(1e16, 3e17)  # 0.01 to 0.3 ETH in wei
            amount_dusc = int(amount_mweth * pool_price)
            
            if pool_price < oracle_price * 1e18 and dusc_balance >= amount_dusc:
                if not try_buy_mweth(w3, account, DEX_ADDRESS, amount_dusc):
                    if mweth_balance >= amount_mweth:
                        try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth)
                    else:
                        amount_mweth = mweth_balance // 2
                        if amount_mweth > 0:
                            try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth)
            elif mweth_balance >= amount_mweth:
                if not try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth):
                    amount_mweth = mweth_balance // 2
                    if amount_mweth > 0:
                        try_sell_mweth(w3, account, DEX_ADDRESS, amount_mweth)
            elif dusc_balance >= amount_dusc:
                try_buy_mweth(w3, account, DEX_ADDRESS, amount_dusc)
            
            time.sleep(10)
        except Exception as e:
            log_message(f"Error in retailer bot 2 loop: {e}", "ERROR")
            time.sleep(10)
    
    log_message("Retailer bot 2 stopped")

if __name__ == "__main__":
    main()
