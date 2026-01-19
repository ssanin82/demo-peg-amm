// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import "../src/DemoStablecoin.sol";
import "../src/SimpleAMMWithPeg.sol";
import "../src/mocks/MockOracle.sol";
import "../src/mocks/MockWETH.sol";

contract PegBehaviorTest is Test {
    DemoStablecoin stable;
    SimpleAMMWithPeg amm;
    MockOracle oracle;
    MockWETH weth;

    address user = address(1);

    function setUp() public {
        // Mock oracle
        oracle = new MockOracle();
        oracle.setPrice(2000e8); // $2000 ETH

        // Deploy stable, WETH, and AMM
        stable = new DemoStablecoin();
        weth = new MockWETH();
        weth.transfer(address(this), 1e18); 
        amm = new SimpleAMMWithPeg(
            address(weth), address(stable), address(oracle)
        );
        stable.setAMM(address(amm));

        // Mint stable to this test contract
        vm.prank(address(amm));
        stable.mint(address(this), 1_000e18); // <-- mint first!

        // Approve AMM to spend tokens
        stable.approve(address(amm), 1_000e18); 
        weth.approve(address(amm), 1e18);

        // Add liquidity once
        amm.addLiquidity(1_000e18, 1e18); // 1000 dUSD + 1 WETH
    }

    function testPegAdjustmentMintsWhenOverpriced() public {
        vm.prank(address(amm));
        stable.mint(address(amm), 1_000e18);
        amm.adjustPeg();
        assertGt(stable.balanceOf(address(amm)), 1_000e18);
    }
}
