// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";

contract MockWETH is ERC20, Ownable {
    address public lendingProtocol;
    address public minterRedeemer;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor() ERC20("Mock WETH", "mWETH") Ownable(msg.sender) {
        _mint(msg.sender, 100_000 ether);
    }

    function setLendingProtocol(address _lendingProtocol) external onlyOwner {
        lendingProtocol = _lendingProtocol;
    }

    function setMinterRedeemer(address _minterRedeemer) external onlyOwner {
        minterRedeemer = _minterRedeemer;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == lendingProtocol || msg.sender == minterRedeemer, "Only authorized");
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == lendingProtocol || msg.sender == minterRedeemer, "Only authorized");
        _burn(from, amount);
        emit Burn(from, amount);
    }
}
