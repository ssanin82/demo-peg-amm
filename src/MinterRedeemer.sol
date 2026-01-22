// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "./DemoStablecoin.sol";
import "./DemoStablecoinUSC.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract MinterRedeemer {
    IERC20 public mweth;
    DemoStablecoin public dusd;
    DemoStablecoinUSC public dusc;
    AggregatorV3Interface public oracle;

    event MintDUSD(address indexed user, uint256 mwethAmount, uint256 dusdAmount);
    event RedeemDUSD(address indexed user, uint256 dusdAmount, uint256 mwethAmount);
    event MintDUSC(address indexed user, uint256 mwethAmount, uint256 duscAmount);
    event RedeemDUSC(address indexed user, uint256 duscAmount, uint256 mwethAmount);

    constructor(
        address _mweth,
        address _dusd,
        address _dusc,
        address _oracle
    ) {
        mweth = IERC20(_mweth);
        dusd = DemoStablecoin(_dusd);
        dusc = DemoStablecoinUSC(_dusc);
        oracle = AggregatorV3Interface(_oracle);
    }

    function getEthPrice() public view returns (uint256) {
        (, int256 price,,,) = oracle.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price) * 1e10; // 8 decimals to 18 decimals
    }

    function mintDUSD(uint256 mwethAmount) external returns (uint256 dusdAmount) {
        uint256 ethPrice = getEthPrice();
        dusdAmount = (mwethAmount * ethPrice) / 1e18; // $1 per stablecoin
        
        mweth.transferFrom(msg.sender, address(this), mwethAmount);
        dusd.mint(msg.sender, dusdAmount);
        
        emit MintDUSD(msg.sender, mwethAmount, dusdAmount);
    }

    function redeemDUSD(uint256 dusdAmount) external returns (uint256 mwethAmount) {
        uint256 ethPrice = getEthPrice();
        mwethAmount = (dusdAmount * 1e18) / ethPrice; // $1 per stablecoin
        
        dusd.transferFrom(msg.sender, address(this), dusdAmount);
        dusd.burn(address(this), dusdAmount);
        mweth.transfer(msg.sender, mwethAmount);
        
        emit RedeemDUSD(msg.sender, dusdAmount, mwethAmount);
    }

    function mintDUSC(uint256 mwethAmount) external returns (uint256 duscAmount) {
        uint256 ethPrice = getEthPrice();
        duscAmount = (mwethAmount * ethPrice) / 1e18; // $1 per stablecoin
        
        mweth.transferFrom(msg.sender, address(this), mwethAmount);
        dusc.mint(msg.sender, duscAmount);
        
        emit MintDUSC(msg.sender, mwethAmount, duscAmount);
    }

    function redeemDUSC(uint256 duscAmount) external returns (uint256 mwethAmount) {
        uint256 ethPrice = getEthPrice();
        mwethAmount = (duscAmount * 1e18) / ethPrice; // $1 per stablecoin
        
        dusc.transferFrom(msg.sender, address(this), duscAmount);
        dusc.burn(address(this), duscAmount);
        mweth.transfer(msg.sender, mwethAmount);
        
        emit RedeemDUSC(msg.sender, duscAmount, mwethAmount);
    }
}
