#!/bin/bash

# Script to stop the entire ecosystem
set -e

echo "Stopping blockchain ecosystem..."

# Activate kill switch
echo "1" > .kill_switch
echo "Kill switch activated"

# Stop Python bots
if [ -f ".oracle_pid" ]; then
    ORACLE_PID=$(cat .oracle_pid)
    if ps -p $ORACLE_PID > /dev/null; then
        kill $ORACLE_PID
        echo "Stopped Oracle bot"
    fi
    rm .oracle_pid
fi

if [ -f ".retailer1_pid" ]; then
    RETAILER1_PID=$(cat .retailer1_pid)
    if ps -p $RETAILER1_PID > /dev/null; then
        kill $RETAILER1_PID
        echo "Stopped Retailer bot 1"
    fi
    rm .retailer1_pid
fi

if [ -f ".retailer2_pid" ]; then
    RETAILER2_PID=$(cat .retailer2_pid)
    if ps -p $RETAILER2_PID > /dev/null; then
        kill $RETAILER2_PID
        echo "Stopped Retailer bot 2"
    fi
    rm .retailer2_pid
fi

if [ -f ".profit1_pid" ]; then
    PROFIT1_PID=$(cat .profit1_pid)
    if ps -p $PROFIT1_PID > /dev/null; then
        kill $PROFIT1_PID
        echo "Stopped Profit bot 1"
    fi
    rm .profit1_pid
fi

if [ -f ".profit2_pid" ]; then
    PROFIT2_PID=$(cat .profit2_pid)
    if ps -p $PROFIT2_PID > /dev/null; then
        kill $PROFIT2_PID
        echo "Stopped Profit bot 2"
    fi
    rm .profit2_pid
fi

# Stop Anvil if we started it
if [ -f ".anvil_pid" ]; then
    ANVIL_PID=$(cat .anvil_pid)
    if ps -p $ANVIL_PID > /dev/null; then
        kill $ANVIL_PID
        echo "Stopped Anvil"
    fi
    rm .anvil_pid
fi

# Kill any remaining Python processes related to bots
pkill -f "oracle_bot.py" || true
pkill -f "retailer_bot" || true
pkill -f "profit_bot" || true

echo "Ecosystem stopped!"
