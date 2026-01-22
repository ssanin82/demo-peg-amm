// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "./DemoStablecoin.sol";
import "./DemoStablecoinUSC.sol";

contract SimpleDEX {
    struct Pool {
        IERC20 token0;
        IERC20 token1;
        uint256 reserve0;
        uint256 reserve1;
    }

    Pool public poolDUSD;
    Pool public poolDUSC;

    event SwapDUSDForWETH(address indexed user, uint256 dusdIn, uint256 wethOut);
    event SwapWETHForDUSD(address indexed user, uint256 wethIn, uint256 dusdOut);
    event SwapDUSCForWETH(address indexed user, uint256 duscIn, uint256 wethOut);
    event SwapWETHForDUSC(address indexed user, uint256 wethIn, uint256 duscOut);

    constructor(
        address _dusd,
        address _dusc,
        address _mweth
    ) {
        poolDUSD = Pool({
            token0: IERC20(_dusd),
            token1: IERC20(_mweth),
            reserve0: 0,
            reserve1: 0
        });

        poolDUSC = Pool({
            token0: IERC20(_dusc),
            token1: IERC20(_mweth),
            reserve0: 0,
            reserve1: 0
        });
    }

    function addLiquidityDUSD(uint256 dusdAmount, uint256 mwethAmount) external {
        poolDUSD.token0.transferFrom(msg.sender, address(this), dusdAmount);
        poolDUSD.token1.transferFrom(msg.sender, address(this), mwethAmount);

        poolDUSD.reserve0 += dusdAmount;
        poolDUSD.reserve1 += mwethAmount;
    }

    function addLiquidityDUSC(uint256 duscAmount, uint256 mwethAmount) external {
        poolDUSC.token0.transferFrom(msg.sender, address(this), duscAmount);
        poolDUSC.token1.transferFrom(msg.sender, address(this), mwethAmount);

        poolDUSC.reserve0 += duscAmount;
        poolDUSC.reserve1 += mwethAmount;
    }

    function swapDUSDForWETH(uint256 dusdIn) external returns (uint256 wethOut) {
        poolDUSD.token0.transferFrom(msg.sender, address(this), dusdIn);

        wethOut = (dusdIn * poolDUSD.reserve1) / (poolDUSD.reserve0 + dusdIn);

        poolDUSD.reserve0 += dusdIn;
        poolDUSD.reserve1 -= wethOut;

        poolDUSD.token1.transfer(msg.sender, wethOut);
        emit SwapDUSDForWETH(msg.sender, dusdIn, wethOut);
    }

    function swapWETHForDUSD(uint256 wethIn) external returns (uint256 dusdOut) {
        poolDUSD.token1.transferFrom(msg.sender, address(this), wethIn);

        dusdOut = (wethIn * poolDUSD.reserve0) / (poolDUSD.reserve1 + wethIn);

        poolDUSD.reserve1 += wethIn;
        poolDUSD.reserve0 -= dusdOut;

        poolDUSD.token0.transfer(msg.sender, dusdOut);
        emit SwapWETHForDUSD(msg.sender, wethIn, dusdOut);
    }

    function swapDUSCForWETH(uint256 duscIn) external returns (uint256 wethOut) {
        poolDUSC.token0.transferFrom(msg.sender, address(this), duscIn);

        wethOut = (duscIn * poolDUSC.reserve1) / (poolDUSC.reserve0 + duscIn);

        poolDUSC.reserve0 += duscIn;
        poolDUSC.reserve1 -= wethOut;

        poolDUSC.token1.transfer(msg.sender, wethOut);
        emit SwapDUSCForWETH(msg.sender, duscIn, wethOut);
    }

    function swapWETHForDUSC(uint256 wethIn) external returns (uint256 duscOut) {
        poolDUSC.token1.transferFrom(msg.sender, address(this), wethIn);

        duscOut = (wethIn * poolDUSC.reserve0) / (poolDUSC.reserve1 + wethIn);

        poolDUSC.reserve1 += wethIn;
        poolDUSC.reserve0 -= duscOut;

        poolDUSC.token0.transfer(msg.sender, duscOut);
        emit SwapWETHForDUSC(msg.sender, wethIn, duscOut);
    }

    function getDUSDPoolReserves() external view returns (uint256, uint256) {
        return (poolDUSD.reserve0, poolDUSD.reserve1);
    }

    function getDUSCPoolReserves() external view returns (uint256, uint256) {
        return (poolDUSC.reserve0, poolDUSC.reserve1);
    }

    function getDUSDPrice() external view returns (uint256) {
        if (poolDUSD.reserve1 == 0) return 0;
        return (poolDUSD.reserve0 * 1e18) / poolDUSD.reserve1;
    }

    function getDUSCPrice() external view returns (uint256) {
        if (poolDUSC.reserve1 == 0) return 0;
        return (poolDUSC.reserve0 * 1e18) / poolDUSC.reserve1;
    }
}
