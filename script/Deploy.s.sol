// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DemoStablecoin.sol";
import "../src/SimpleAMMWithPeg.sol";
import "../src/mocks/MockOracle.sol";
import "../src/mocks/MockWETH.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        DemoStablecoin stable = new DemoStablecoin();

        address weth;
        address priceFeed;

        if (block.chainid == 11155111) {
            // -------------------------
            // Sepolia
            // -------------------------
            weth = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
            priceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        } else {
            // -------------------------
            // Anvil / Local
            // -------------------------
            weth = address(new MockWETH());
            MockOracle oracle = new MockOracle();
            oracle.setPrice(2000e8); // $2000 ETH
            priceFeed = address(oracle);
        }

        SimpleAMMWithPeg amm = new SimpleAMMWithPeg(
            weth,
            address(stable),
            priceFeed
        );

        stable.setAMM(address(amm));

        vm.stopBroadcast();
    }
}
