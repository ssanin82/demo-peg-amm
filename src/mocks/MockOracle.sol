// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockOracle {
    int256 private price;
    uint256 public lastUpdateTime;

    function setPrice(int256 _price) external {
        price = _price;
        lastUpdateTime = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256,
            uint256,
            uint256,
            uint80
        )
    {
        return (0, price, 0, lastUpdateTime, 0);
    }

    function getPrice() external view returns (int256) {
        return price;
    }
}

