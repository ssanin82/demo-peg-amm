// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import "../src/DemoStablecoin.sol";
import "../src/DemoStablecoinUSC.sol";
import "../src/mocks/MockWETH.sol";
import "../src/mocks/MockOracle.sol";
import "../src/SimpleDEX.sol";
import "../src/LendingProtocol.sol";
import "../src/MinterRedeemer.sol";

contract EcosystemTest is Test {
    MockWETH mweth;
    DemoStablecoin dusd;
    DemoStablecoinUSC dusc;
    MockOracle oracle;
    SimpleDEX dex;
    LendingProtocol lending;
    MinterRedeemer minterRedeemer;

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);
    address user4 = address(4);

    function setUp() public {
        // Deploy tokens
        mweth = new MockWETH();
        dusd = new DemoStablecoin();
        dusc = new DemoStablecoinUSC();
        oracle = new MockOracle();
        oracle.setPrice(2000e8); // $2000 ETH

        // Deploy core contracts
        dex = new SimpleDEX(address(dusd), address(dusc), address(mweth));
        lending = new LendingProtocol(
            address(mweth),
            address(dusd),
            address(dusc),
            address(oracle)
        );
        minterRedeemer = new MinterRedeemer(
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
    }

    function testMinterRedeemerMintDUSD() public {
        uint256 mwethAmount = 1 ether;
        mweth.mint(address(this), mwethAmount);
        mweth.approve(address(minterRedeemer), mwethAmount);

        uint256 dusdAmount = minterRedeemer.mintDUSD(mwethAmount);
        assertEq(dusd.balanceOf(address(this)), dusdAmount);
        assertGt(dusdAmount, 0);
    }

    function testMinterRedeemerRedeemDUSD() public {
        // First mint
        uint256 mwethAmount = 1 ether;
        mweth.mint(address(this), mwethAmount);
        mweth.approve(address(minterRedeemer), mwethAmount);
        uint256 dusdAmount = minterRedeemer.mintDUSD(mwethAmount);

        // Then redeem
        dusd.approve(address(minterRedeemer), dusdAmount);
        uint256 mwethOut = minterRedeemer.redeemDUSD(dusdAmount);
        assertGt(mwethOut, 0);
    }

    function testDEXSwap() public {
        // Setup liquidity
        uint256 dusdAmount = 1000 ether;
        uint256 mwethAmount = 1 ether;
        
        mweth.mint(address(this), mwethAmount);
        mweth.mint(address(this), 10 ether); // For minting
        mweth.approve(address(minterRedeemer), 10 ether);
        minterRedeemer.mintDUSD(10 ether);
        
        dusd.approve(address(dex), dusdAmount);
        mweth.approve(address(dex), mwethAmount);
        dex.addLiquidityDUSD(dusdAmount, mwethAmount);

        // Swap
        uint256 swapAmount = 100 ether;
        dusd.approve(address(dex), swapAmount);
        uint256 wethOut = dex.swapDUSDForWETH(swapAmount);
        assertGt(wethOut, 0);
    }

    function testLendingDepositAndBorrow() public {
        // Add reserves
        uint256 reserveDUSD = 10000 ether;
        uint256 reserveDUSC = 10000 ether;
        
        mweth.mint(address(this), 20 ether);
        mweth.approve(address(minterRedeemer), 20 ether);
        minterRedeemer.mintDUSD(10 ether);
        minterRedeemer.mintDUSC(10 ether);
        
        dusd.approve(address(lending), reserveDUSD);
        dusc.approve(address(lending), reserveDUSC);
        lending.addReserves(reserveDUSD, reserveDUSC);

        // Deposit collateral and borrow
        uint256 collateral = 2 ether;
        mweth.mint(user1, collateral);
        vm.startPrank(user1);
        mweth.approve(address(lending), collateral);
        lending.depositCollateral(collateral);
        
        uint256 borrowDUSD = 1000 ether;
        uint256 borrowDUSC = 500 ether;
        lending.borrow(borrowDUSD, borrowDUSC);
        vm.stopPrank();

        assertEq(dusd.balanceOf(user1), borrowDUSD);
        assertEq(dusc.balanceOf(user1), borrowDUSC);
    }

    function testLendingLiquidation() public {
        // Setup
        uint256 reserveDUSD = 10000 ether;
        uint256 reserveDUSC = 10000 ether;
        
        mweth.mint(address(this), 20 ether);
        mweth.approve(address(minterRedeemer), 20 ether);
        minterRedeemer.mintDUSD(10 ether);
        minterRedeemer.mintDUSC(10 ether);
        
        dusd.approve(address(lending), reserveDUSD);
        dusc.approve(address(lending), reserveDUSC);
        lending.addReserves(reserveDUSD, reserveDUSC);

        // User deposits and borrows
        uint256 collateral = 2 ether;
        mweth.mint(user1, collateral);
        vm.startPrank(user1);
        mweth.approve(address(lending), collateral);
        lending.depositCollateral(collateral);
        lending.borrow(3000 ether, 0); // Borrow close to limit
        vm.stopPrank();

        // Price drops, making position liquidatable
        oracle.setPrice(1000e8); // Price drops to $1000

        // Check if liquidatable
        bool canLiquidate = lending.canLiquidate(user1);
        assertTrue(canLiquidate);

        // Liquidate
        vm.startPrank(user2);
        dusd.mint(user2, 3000 ether);
        dusd.approve(address(lending), 3000 ether);
        lending.liquidate(user1);
        vm.stopPrank();

        // Check that position was partially liquidated
        uint256 newRatio = lending.getCollateralizationRatio(user1);
        assertGe(newRatio, 120e16); // Should be at least 120%
    }

    function testLendingRepay() public {
        // Setup reserves
        uint256 reserveDUSD = 10000 ether;
        uint256 reserveDUSC = 10000 ether;
        
        mweth.mint(address(this), 20 ether);
        mweth.approve(address(minterRedeemer), 20 ether);
        minterRedeemer.mintDUSD(10 ether);
        minterRedeemer.mintDUSC(10 ether);
        
        dusd.approve(address(lending), reserveDUSD);
        dusc.approve(address(lending), reserveDUSC);
        lending.addReserves(reserveDUSD, reserveDUSC);

        // Borrow
        uint256 collateral = 2 ether;
        mweth.mint(user1, collateral);
        vm.startPrank(user1);
        mweth.approve(address(lending), collateral);
        lending.depositCollateral(collateral);
        lending.borrow(1000 ether, 500 ether);
        
        // Repay
        dusd.approve(address(lending), 1000 ether);
        dusc.approve(address(lending), 500 ether);
        lending.repay(1000 ether, 500 ether);
        vm.stopPrank();

        // Check debt is zero
        (uint256 collateralAmount, uint256 dusdDebt, uint256 duscDebt) = lending.positions(user1);
        assertEq(dusdDebt, 0);
        assertEq(duscDebt, 0);
    }
}
