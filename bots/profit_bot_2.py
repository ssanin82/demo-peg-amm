"""
Profit bot 2 - arbitrage and liquidation bot (monitors wallet 3)
"""
import time
from web3 import Web3
from config import RPC_URL, DEX_ADDRESS, DUSD_ADDRESS, DUSC_ADDRESS, MWETH_ADDRESS, WALLET_4_KEY, LENDING_ADDRESS, ORACLE_ADDRESS, WALLET_3_KEY
from utils import log_message, check_kill_switch, log_statistics, log_wallet_balances, format_ether, get_balance

def get_oracle_price(w3: Web3, oracle_address: str) -> float:
    """Get current ETH price from oracle"""
    abi = [{"inputs": [], "name": "latestRoundData", "outputs": [{"name": "", "type": "uint80"}, {"name": "", "type": "int256"}, {"name": "", "type": "uint256"}, {"name": "", "type": "uint256"}, {"name": "", "type": "uint80"}], "stateMutability": "view", "type": "function"}]
    contract = w3.eth.contract(address=oracle_address, abi=abi)
    _, price, _, _, _ = contract.functions.latestRoundData().call()
    return float(price) / 1e8

def get_pool_prices(w3: Web3, dex_address: str) -> tuple:
    """Get both pool prices"""
    abi = [
        {"inputs": [], "name": "getDUSDPrice", "outputs": [{"name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
        {"inputs": [], "name": "getDUSCPrice", "outputs": [{"name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"}
    ]
    contract = w3.eth.contract(address=dex_address, abi=abi)
    dusd_price = float(contract.functions.getDUSDPrice().call()) / 1e18
    dusc_price = float(contract.functions.getDUSCPrice().call()) / 1e18
    return dusd_price, dusc_price

def check_arbitrage_opportunity(w3: Web3, dex_address: str, oracle_price: float) -> tuple:
    """Check for arbitrage opportunities between pools"""
    dusd_price, dusc_price = get_pool_prices(w3, dex_address)
    oracle_price_wei = oracle_price * 1e18
    
    price_diff = abs(dusd_price - dusc_price)
    if price_diff > dusd_price * 0.01:  # 1% difference
        if dusd_price < dusc_price:
            return ("dusd_to_dusc", dusd_price, dusc_price)
        else:
            return ("dusc_to_dusd", dusd_price, dusc_price)
    return (None, dusd_price, dusc_price)

def execute_arbitrage(w3: Web3, account, dex_address: str, direction: str, amount: int) -> bool:
    """Execute arbitrage trade"""
    try:
        if direction == "dusd_to_dusc":
            abi = [
                {"inputs": [{"name": "dusdIn", "type": "uint256"}], "name": "swapDUSDForWETH", "outputs": [{"name": "wethOut", "type": "uint256"}], "stateMutability": "nonpayable", "type": "function"},
                {"inputs": [{"name": "wethIn", "type": "uint256"}], "name": "swapWETHForDUSC", "outputs": [{"name": "duscOut", "type": "uint256"}], "stateMutability": "nonpayable", "type": "function"}
            ]
            contract = w3.eth.contract(address=dex_address, abi=abi)
            
            approve_abi = [{"inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}], "name": "approve", "outputs": [{"name": "", "type": "bool"}], "stateMutability": "nonpayable", "type": "function"}]
            dusd_contract = w3.eth.contract(address=DUSD_ADDRESS, abi=approve_abi)
            dusd_contract.functions.approve(dex_address, amount).transact({
                "from": account.address,
                "gas": 100000,
                "gasPrice": w3.eth.gas_price
            })
            
            tx1 = contract.functions.swapDUSDForWETH(amount).build_transaction({
                "from": account.address,
                "nonce": w3.eth.get_transaction_count(account.address),
                "gas": 200000,
                "gasPrice": w3.eth.gas_price
            })
            signed_tx1 = account.sign_transaction(tx1)
            tx_hash1 = w3.eth.send_raw_transaction(signed_tx1.rawTransaction)
            receipt1 = w3.eth.wait_for_transaction_receipt(tx_hash1)
            
            mweth_balance = get_balance(w3, account.address, MWETH_ADDRESS)
            mweth_contract = w3.eth.contract(address=MWETH_ADDRESS, abi=approve_abi)
            mweth_contract.functions.approve(dex_address, mweth_balance).transact({
                "from": account.address,
                "gas": 100000,
                "gasPrice": w3.eth.gas_price
            })
            
            tx2 = contract.functions.swapWETHForDUSC(mweth_balance).build_transaction({
                "from": account.address,
                "nonce": w3.eth.get_transaction_count(account.address),
                "gas": 200000,
                "gasPrice": w3.eth.gas_price
            })
            signed_tx2 = account.sign_transaction(tx2)
            tx_hash2 = w3.eth.send_raw_transaction(signed_tx2.rawTransaction)
            receipt2 = w3.eth.wait_for_transaction_receipt(tx_hash2)
            
            log_message(f"Arbitrage executed: dUSD->mWETH->dUSC (tx1: {tx_hash1.hex()}, tx2: {tx_hash2.hex()})")
            log_statistics("AMM_TRANSACTION", {
                "type": "arbitrage",
                "direction": direction,
                "amount": str(amount),
                "tx_hash": tx_hash1.hex()
            })
            return True
    except Exception as e:
        log_message(f"Arbitrage failed: {e}", "ERROR")
        return False

def check_liquidation(w3: Web3, lending_address: str, target_wallet: str) -> bool:
    """Check if target wallet can be liquidated"""
    abi = [{"inputs": [{"name": "user", "type": "address"}], "name": "canLiquidate", "outputs": [{"name": "", "type": "bool"}], "stateMutability": "view", "type": "function"}]
    contract = w3.eth.contract(address=lending_address, abi=abi)
    return contract.functions.canLiquidate(target_wallet).call()

def execute_liquidation(w3: Web3, account, lending_address: str, target_wallet: str) -> bool:
    """Execute liquidation"""
    try:
        abi = [{"inputs": [{"name": "user", "type": "address"}], "name": "liquidate", "outputs": [], "stateMutability": "nonpayable", "type": "function"}]
        contract = w3.eth.contract(address=lending_address, abi=abi)
        
        tx = contract.functions.liquidate(target_wallet).build_transaction({
            "from": account.address,
            "nonce": w3.eth.get_transaction_count(account.address),
            "gas": 500000,
            "gasPrice": w3.eth.gas_price
        })
        
        signed_tx = account.sign_transaction(tx)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        log_message(f"Liquidation executed for {target_wallet} (tx: {tx_hash.hex()})")
        log_statistics("LENDING", {
            "type": "liquidation",
            "target": target_wallet,
            "liquidator": account.address,
            "tx_hash": tx_hash.hex()
        })
        return True
    except Exception as e:
        log_message(f"Liquidation failed: {e}", "ERROR")
        return False

def borrow_if_needed(w3: Web3, account, lending_address: str, dusd_needed: int, dusc_needed: int) -> bool:
    """Borrow tokens if needed and profitable"""
    try:
        mweth_balance = get_balance(w3, account.address, MWETH_ADDRESS)
        if mweth_balance == 0:
            return False
        
        abi = [
            {"inputs": [{"name": "amount", "type": "uint256"}], "name": "depositCollateral", "outputs": [], "stateMutability": "nonpayable", "type": "function"},
            {"inputs": [{"name": "dusdAmount", "type": "uint256"}, {"name": "duscAmount", "type": "uint256"}], "name": "borrow", "outputs": [], "stateMutability": "nonpayable", "type": "function"}
        ]
        contract = w3.eth.contract(address=lending_address, abi=abi)
        
        approve_abi = [{"inputs": [{"name": "spender", "type": "address"}, {"name": "amount", "type": "uint256"}], "name": "approve", "outputs": [{"name": "", "type": "bool"}], "stateMutability": "nonpayable", "type": "function"}]
        mweth_contract = w3.eth.contract(address=MWETH_ADDRESS, abi=approve_abi)
        mweth_contract.functions.approve(lending_address, mweth_balance).transact({
            "from": account.address,
            "gas": 100000,
            "gasPrice": w3.eth.gas_price
        })
        
        contract.functions.depositCollateral(mweth_balance).transact({
            "from": account.address,
            "gas": 200000,
            "gasPrice": w3.eth.gas_price
        })
        
        if dusd_needed > 0 or dusc_needed > 0:
            contract.functions.borrow(dusd_needed, dusc_needed).transact({
                "from": account.address,
                "gas": 300000,
                "gasPrice": w3.eth.gas_price
            })
            log_statistics("LENDING", {
                "type": "borrow",
                "borrower": account.address,
                "dusd_amount": str(dusd_needed),
                "dusc_amount": str(dusc_needed)
            })
        
        return True
    except Exception as e:
        log_message(f"Borrow failed: {e}", "ERROR")
        return False

def main():
    """Main profit bot 2 loop"""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if not w3.is_connected():
        log_message("Failed to connect to RPC", "ERROR")
        return
    
    if not WALLET_4_KEY:
        log_message("WALLET_4_KEY not set", "ERROR")
        return
    
    account = w3.eth.account.from_key(WALLET_4_KEY)
    target_wallet = w3.eth.account.from_key(WALLET_3_KEY).address
    
    log_message(f"Profit bot 2 started (wallet: {account.address}, monitoring: {target_wallet})")
    
    while not check_kill_switch():
        try:
            oracle_price = get_oracle_price(w3, ORACLE_ADDRESS)
            log_wallet_balances(w3, account.address, "Profit Bot 2", 
                              MWETH_ADDRESS, DUSD_ADDRESS, DUSC_ADDRESS)
            
            if check_liquidation(w3, LENDING_ADDRESS, target_wallet):
                dusd_balance = get_balance(w3, account.address, DUSD_ADDRESS)
                dusc_balance = get_balance(w3, account.address, DUSC_ADDRESS)
                
                if dusd_balance < 1000e18 or dusc_balance < 1000e18:
                    borrow_if_needed(w3, account, LENDING_ADDRESS, 1000e18, 1000e18)
                
                execute_liquidation(w3, account, LENDING_ADDRESS, target_wallet)
            
            direction, dusd_price, dusc_price = check_arbitrage_opportunity(w3, DEX_ADDRESS, oracle_price)
            if direction:
                dusd_balance = get_balance(w3, account.address, DUSD_ADDRESS)
                dusc_balance = get_balance(w3, account.address, DUSC_ADDRESS)
                
                if direction == "dusd_to_dusc" and dusd_balance > 0:
                    amount = min(dusd_balance // 2, 1000e18)
                    if amount > 0:
                        execute_arbitrage(w3, account, DEX_ADDRESS, direction, amount)
                elif direction == "dusc_to_dusd" and dusc_balance > 0:
                    amount = min(dusc_balance // 2, 1000e18)
                    if amount > 0:
                        execute_arbitrage(w3, account, DEX_ADDRESS, direction, amount)
            
            time.sleep(15)
        except Exception as e:
            log_message(f"Error in profit bot 2 loop: {e}", "ERROR")
            time.sleep(15)
    
    log_message("Profit bot 2 stopped")

if __name__ == "__main__":
    main()
