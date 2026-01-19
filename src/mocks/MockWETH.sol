// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Mock WETH", "mWETH") {
        _mint(msg.sender, 100_000 ether);
    }
}
