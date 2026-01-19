// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import "../src/DemoStablecoin.sol";
import "../src/SimpleAMMWithPeg.sol";
import "../src/mocks/MockOracle.sol";

contract PegBehaviorTest is Test {
    DemoStablecoin stable;
    SimpleAMMWithPeg amm;
    MockOracle oracle;

    address user = address(1);

    function setUp() public {
        oracle = new MockOracle();
        oracle.setPrice(2000e8); // $2000 ETH

        stable = new DemoStablecoin();
        amm = new SimpleAMMWithPeg(
            address(0xdead), // mock WETH
            address(stable),
            address(oracle)
        );

        stable.setAMM(address(amm));
    }

    function testPegAdjustmentMintsWhenOverpriced() public {
        stable.mint(address(amm), 1_000e18);

        amm.adjustPeg();

        assertGt(stable.balanceOf(address(amm)), 1_000e18);
    }
}
