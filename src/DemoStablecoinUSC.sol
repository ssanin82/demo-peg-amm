// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";

contract DemoStablecoinUSC is ERC20, Ownable {
    address public amm;
    address public minterRedeemer;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor() ERC20("Demo USC", "dUSC") Ownable(msg.sender) {}

    function setAMM(address _amm) external onlyOwner {
        amm = _amm;
    }

    function setMinterRedeemer(address _minterRedeemer) external onlyOwner {
        minterRedeemer = _minterRedeemer;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == amm || msg.sender == minterRedeemer, "Only AMM or MinterRedeemer");
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == amm || msg.sender == minterRedeemer, "Only AMM or MinterRedeemer");
        _burn(from, amount);
        emit Burn(from, amount);
    }
}
