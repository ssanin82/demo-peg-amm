// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "./DemoStablecoin.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract SimpleAMMWithPeg {
    IERC20 public weth;
    DemoStablecoin public stable;
    AggregatorV3Interface public priceFeed;

    uint256 public tokenReserve;
    uint256 public wethReserve;

    uint256 public constant TARGET_PRICE = 1e18;     // $1.00
    uint256 public constant PEG_TOLERANCE = 5e16;    // ±5%

    constructor(
        address _weth,
        address _stable,
        address _priceFeed
    ) {
        weth = IERC20(_weth);
        stable = DemoStablecoin(_stable);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /* ------------------ Liquidity ------------------ */

    function addLiquidity(uint256 stableAmount, uint256 wethAmount) external {
        stable.transferFrom(msg.sender, address(this), stableAmount);
        weth.transferFrom(msg.sender, address(this), wethAmount);

        tokenReserve += stableAmount;
        wethReserve += wethAmount;
    }

    /* ------------------ Swaps ------------------ */

    function swapWethForStable(uint256 wethIn) external returns (uint256 stableOut) {
        weth.transferFrom(msg.sender, address(this), wethIn);

        stableOut = (wethIn * tokenReserve) / (wethReserve + wethIn);

        wethReserve += wethIn;
        tokenReserve -= stableOut;

        stable.transfer(msg.sender, stableOut);
    }

    function swapStableForWeth(uint256 stableIn) external returns (uint256 wethOut) {
        stable.transferFrom(msg.sender, address(this), stableIn);

        wethOut = (stableIn * wethReserve) / (tokenReserve + stableIn);

        tokenReserve += stableIn;
        wethReserve -= wethOut;

        weth.transfer(msg.sender, wethOut);
    }

    /* ------------------ Pricing ------------------ */

    function getEthUsdPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price) * 1e10; // 8 → 18 decimals
    }

    function stableUsdPrice() public view returns (uint256) {
        uint256 ethPerStable = (wethReserve * 1e18) / tokenReserve;
        return (ethPerStable * getEthUsdPrice()) / 1e18;
    }

    /* ------------------ Peg Adjustment ------------------ */

    function adjustPeg() external {
        uint256 price = stableUsdPrice();

        if (price > TARGET_PRICE + PEG_TOLERANCE) {
            uint256 mintAmount = tokenReserve / 20; // 5%
            stable.mint(address(this), mintAmount);
            tokenReserve += mintAmount;
        }

        if (price < TARGET_PRICE - PEG_TOLERANCE) {
            uint256 burnAmount = tokenReserve / 20;
            stable.burn(address(this), burnAmount);
            tokenReserve -= burnAmount;
        }
    }
}
