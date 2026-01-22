#!/bin/bash

# Script to run the entire ecosystem
set -e

echo "Starting blockchain ecosystem..."

# Check if Anvil is running, if not start it
if ! pgrep -f "anvil" > /dev/null; then
    echo "Starting Anvil..."
    anvil > anvil.log 2>&1 &
    ANVIL_PID=$!
    echo $ANVIL_PID > .anvil_pid
    sleep 3
else
    echo "Anvil already running"
fi

# Deploy contracts
echo "Deploying contracts..."
forge script script/DeployEcosystem.s.sol:DeployEcosystem --rpc-url http://localhost:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Extract contract addresses from deployment (you may need to parse the output)
# For now, we'll use environment variables or a config file
echo "Contracts deployed. Please update .env with contract addresses."

# Create kill switch file (0 = running)
echo "0" > .kill_switch

# Start Python bots
echo "Starting Python bots..."

# Install Python dependencies if needed
if [ ! -d "bots/venv" ]; then
    echo "Creating Python virtual environment..."
    cd bots
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    cd ..
fi

cd bots
source venv/bin/activate

# Start bots in background
echo "Starting Oracle bot..."
python oracle_bot.py > ../oracle_bot.log 2>&1 &
ORACLE_PID=$!
echo $ORACLE_PID > ../.oracle_pid

# Wait for oracle to set initial price
sleep 5

echo "Starting Retailer bot 1..."
python retailer_bot_1.py > ../retailer_bot_1.log 2>&1 &
RETAILER1_PID=$!
echo $RETAILER1_PID > ../.retailer1_pid

echo "Starting Retailer bot 2..."
python retailer_bot_2.py > ../retailer_bot_2.log 2>&1 &
RETAILER2_PID=$!
echo $RETAILER2_PID > ../.retailer2_pid

echo "Starting Profit bot 1..."
python profit_bot_1.py > ../profit_bot_1.log 2>&1 &
PROFIT1_PID=$!
echo $PROFIT1_PID > ../.profit1_pid

echo "Starting Profit bot 2..."
python profit_bot_2.py > ../profit_bot_2.log 2>&1 &
PROFIT2_PID=$!
echo $PROFIT2_PID > ../.profit2_pid

cd ..

echo "Ecosystem started!"
echo "All processes are running in the background."
echo "Logs are in: ecosystem.log, statistics.log, and individual bot logs"
echo "Use ./stop_ecosystem.sh to stop everything"
