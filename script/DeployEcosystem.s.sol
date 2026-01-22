// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DemoStablecoin.sol";
import "../src/DemoStablecoinUSC.sol";
import "../src/mocks/MockWETH.sol";
import "../src/mocks/MockOracle.sol";
import "../src/SimpleDEX.sol";
import "../src/LendingProtocol.sol";
import "../src/MinterRedeemer.sol";

contract DeployEcosystem is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy tokens
        MockWETH mweth = new MockWETH();
        DemoStablecoin dusd = new DemoStablecoin();
        DemoStablecoinUSC dusc = new DemoStablecoinUSC();
        MockOracle oracle = new MockOracle();
        oracle.setPrice(2000e8); // Initial price $2000

        // Deploy core contracts
        SimpleDEX dex = new SimpleDEX(address(dusd), address(dusc), address(mweth));
        LendingProtocol lending = new LendingProtocol(
            address(mweth),
            address(dusd),
            address(dusc),
            address(oracle)
        );
        MinterRedeemer minterRedeemer = new MinterRedeemer(
            address(mweth),
            address(dusd),
            address(dusc),
            address(oracle)
        );

        // Set permissions
        dusd.setMinterRedeemer(address(minterRedeemer));
        dusc.setMinterRedeemer(address(minterRedeemer));
        mweth.setMinterRedeemer(address(minterRedeemer));
        mweth.setLendingProtocol(address(lending));

        // Initialize AMM pools
        // Mint 6000 dUSD, 6000 dUSC, 4 mWETH for DEX
        uint256 ethPrice = 2000e18; // $2000
        uint256 mwethForDex = 4 ether;
        uint256 dusdForDex = 6000 ether;
        uint256 duscForDex = 6000 ether;

        // Mint mWETH for DEX
        mweth.mint(address(this), mwethForDex);
        // Mint dUSD for DEX via minterRedeemer
        uint256 mwethForDUSD = dusdForDex * 1e18 / ethPrice;
        mweth.mint(address(this), mwethForDUSD);
        mweth.approve(address(minterRedeemer), mwethForDUSD);
        minterRedeemer.mintDUSD(mwethForDUSD);
        // Mint dUSC for DEX via minterRedeemer
        uint256 mwethForDUSC = duscForDex * 1e18 / ethPrice;
        mweth.mint(address(this), mwethForDUSC);
        mweth.approve(address(minterRedeemer), mwethForDUSC);
        minterRedeemer.mintDUSC(mwethForDUSC);

        // Approve and add liquidity to pools
        dusd.approve(address(dex), dusdForDex);
        dusc.approve(address(dex), duscForDex);
        mweth.approve(address(dex), mwethForDex);
        dex.addLiquidityDUSD(dusdForDex, 2 ether);
        dex.addLiquidityDUSC(duscForDex, 2 ether);

        // Initialize lending protocol reserves
        // Mint 10000 dUSD and 10000 dUSC for lending protocol
        uint256 dusdForLending = 10000 ether;
        uint256 duscForLending = 10000 ether;
        uint256 mwethForLendingDUSD = dusdForLending * 1e18 / ethPrice;
        mweth.mint(address(this), mwethForLendingDUSD);
        mweth.approve(address(minterRedeemer), mwethForLendingDUSD);
        minterRedeemer.mintDUSD(mwethForLendingDUSD);
        uint256 mwethForLendingDUSC = duscForLending * 1e18 / ethPrice;
        mweth.mint(address(this), mwethForLendingDUSC);
        mweth.approve(address(minterRedeemer), mwethForLendingDUSC);
        minterRedeemer.mintDUSC(mwethForLendingDUSC);
        dusd.transfer(address(lending), dusdForLending);
        dusc.transfer(address(lending), duscForLending);
        lending.addReserves(dusdForLending, duscForLending);

        // Mint initial balances for wallets
        // Wallet 1: 2000 dUSD
        uint256 mwethForWallet1 = 2000 ether * 1e18 / ethPrice;
        mweth.mint(address(this), mwethForWallet1);
        mweth.approve(address(minterRedeemer), mwethForWallet1);
        minterRedeemer.mintDUSD(mwethForWallet1);
        dusd.transfer(vm.addr(1), 2000 ether);

        // Wallet 2: 2000 dUSC
        uint256 mwethForWallet2 = 2000 ether * 1e18 / ethPrice;
        mweth.mint(address(this), mwethForWallet2);
        mweth.approve(address(minterRedeemer), mwethForWallet2);
        minterRedeemer.mintDUSC(mwethForWallet2);
        dusc.transfer(vm.addr(2), 2000 ether);

        // Wallet 3: 1 mWETH
        mweth.mint(vm.addr(3), 1 ether);

        // Wallet 4: 1 mWETH
        mweth.mint(vm.addr(4), 1 ether);

        // Log deployment addresses
        console.log("=== Deployment Addresses ===");
        console.log("mWETH:", address(mweth));
        console.log("dUSD:", address(dusd));
        console.log("dUSC:", address(dusc));
        console.log("Oracle:", address(oracle));
        console.log("DEX:", address(dex));
        console.log("Lending:", address(lending));
        console.log("MinterRedeemer:", address(minterRedeemer));
        console.log("Wallet 1:", vm.addr(1));
        console.log("Wallet 2:", vm.addr(2));
        console.log("Wallet 3:", vm.addr(3));
        console.log("Wallet 4:", vm.addr(4));

        vm.stopBroadcast();
    }
}
