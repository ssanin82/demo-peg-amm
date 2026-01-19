// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";

contract DemoStablecoin is ERC20, Ownable {
    address public amm;

    constructor() ERC20("Demo USD", "dUSD") Ownable(msg.sender) {}

    function setAMM(address _amm) external onlyOwner {
        amm = _amm;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == amm, "Only AMM");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == amm, "Only AMM");
        _burn(from, amount);
    }
}
