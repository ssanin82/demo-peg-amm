// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "./DemoStablecoin.sol";
import "./DemoStablecoinUSC.sol";
import "./mocks/MockOracle.sol";
import "./interfaces/AggregatorV3Interface.sol";

contract LendingProtocol {
    IERC20 public mweth;
    DemoStablecoin public dusd;
    DemoStablecoinUSC public dusc;
    AggregatorV3Interface public oracle;

    uint256 public constant COLLATERALIZATION_RATIO = 150e16; // 150%
    uint256 public constant LIQUIDATION_THRESHOLD = 120e16; // 120%
    uint256 public constant LIQUIDATION_BONUS = 5e16; // 5%

    struct Position {
        uint256 collateralAmount; // mWETH
        uint256 dusdDebt;
        uint256 duscDebt;
    }

    mapping(address => Position) public positions;
    uint256 public dusdReserves;
    uint256 public duscReserves;

    event DepositCollateral(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 dusdAmount, uint256 duscAmount);
    event Repay(address indexed user, uint256 dusdAmount, uint256 duscAmount);
    event Liquidate(address indexed user, address indexed liquidator, uint256 collateralSeized, uint256 debtRepaid);

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

    function depositCollateral(uint256 amount) external {
        mweth.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].collateralAmount += amount;
        emit DepositCollateral(msg.sender, amount);
    }

    function borrow(uint256 dusdAmount, uint256 duscAmount) external {
        require(dusdAmount <= dusdReserves, "Insufficient dUSD reserves");
        require(duscAmount <= duscReserves, "Insufficient dUSC reserves");

        Position storage pos = positions[msg.sender];
        pos.dusdDebt += dusdAmount;
        pos.duscDebt += duscAmount;

        uint256 totalDebtValue = (pos.dusdDebt * 1e18) + (pos.duscDebt * 1e18);
        uint256 collateralValue = (pos.collateralAmount * getEthPrice()) / 1e18;
        uint256 collateralizationRatio = (collateralValue * 1e18) / totalDebtValue;

        require(collateralizationRatio >= COLLATERALIZATION_RATIO, "Insufficient collateral");

        dusdReserves -= dusdAmount;
        duscReserves -= duscAmount;

        dusd.mint(msg.sender, dusdAmount);
        dusc.mint(msg.sender, duscAmount);

        emit Borrow(msg.sender, dusdAmount, duscAmount);
    }

    function repay(uint256 dusdAmount, uint256 duscAmount) external {
        Position storage pos = positions[msg.sender];
        require(pos.dusdDebt >= dusdAmount, "Repaying more dUSD than debt");
        require(pos.duscDebt >= duscAmount, "Repaying more dUSC than debt");

        dusd.transferFrom(msg.sender, address(this), dusdAmount);
        dusc.transferFrom(msg.sender, address(this), duscAmount);

        pos.dusdDebt -= dusdAmount;
        pos.duscDebt -= duscAmount;

        dusdReserves += dusdAmount;
        duscReserves += duscAmount;

        dusd.burn(address(this), dusdAmount);
        dusc.burn(address(this), duscAmount);

        emit Repay(msg.sender, dusdAmount, duscAmount);
    }

    function withdrawCollateral(uint256 amount) external {
        Position storage pos = positions[msg.sender];
        require(pos.collateralAmount >= amount, "Insufficient collateral");

        uint256 totalDebtValue = (pos.dusdDebt * 1e18) + (pos.duscDebt * 1e18);
        uint256 newCollateralValue = ((pos.collateralAmount - amount) * getEthPrice()) / 1e18;
        
        if (totalDebtValue > 0) {
            uint256 newCollateralizationRatio = (newCollateralValue * 1e18) / totalDebtValue;
            require(newCollateralizationRatio >= COLLATERALIZATION_RATIO, "Would violate collateralization ratio");
        }

        pos.collateralAmount -= amount;
        mweth.transfer(msg.sender, amount);
    }

    function getCollateralizationRatio(address user) external view returns (uint256) {
        Position memory pos = positions[user];
        uint256 totalDebtValue = (pos.dusdDebt * 1e18) + (pos.duscDebt * 1e18);
        if (totalDebtValue == 0) return type(uint256).max;
        
        uint256 collateralValue = (pos.collateralAmount * getEthPrice()) / 1e18;
        return (collateralValue * 1e18) / totalDebtValue;
    }

    function canLiquidate(address user) external view returns (bool) {
        Position memory pos = positions[user];
        if (pos.collateralAmount == 0) return false;

        uint256 totalDebtValue = (pos.dusdDebt * 1e18) + (pos.duscDebt * 1e18);
        if (totalDebtValue == 0) return false;

        uint256 collateralValue = (pos.collateralAmount * getEthPrice()) / 1e18;
        uint256 collateralizationRatio = (collateralValue * 1e18) / totalDebtValue;

        return collateralizationRatio < LIQUIDATION_THRESHOLD;
    }

    function liquidate(address user) external {
        require(canLiquidate(user), "Position not liquidatable");
        
        Position storage pos = positions[user];
        uint256 totalDebtValue = (pos.dusdDebt * 1e18) + (pos.duscDebt * 1e18);
        uint256 collateralValue = (pos.collateralAmount * getEthPrice()) / 1e18;
        
        // Calculate how much debt to repay to restore to 150% collateralization
        // targetCollateralValue = totalDebtValue * 1.5
        // We want: (collateralValue - seizedValue) = (totalDebtValue - repaidValue) * 1.5
        // seizedValue = repaidValue * (1 + bonus) / ethPrice
        // Solving: repaidValue = (collateralValue - totalDebtValue * 1.5) / (1 + bonus/ethPrice - 1.5)
        // Simplified: repay enough to get back to 150%
        uint256 targetCollateralValue = (totalDebtValue * COLLATERALIZATION_RATIO) / 1e18;
        uint256 excessCollateralValue = collateralValue - targetCollateralValue;
        
        // Calculate debt to repay (proportional to excess collateral)
        uint256 debtToRepayValue = excessCollateralValue;
        if (debtToRepayValue > totalDebtValue) {
            debtToRepayValue = totalDebtValue;
        }
        
        // Repay debt proportionally
        uint256 dusdToRepay = (pos.dusdDebt * debtToRepayValue) / totalDebtValue;
        uint256 duscToRepay = (pos.duscDebt * debtToRepayValue) / totalDebtValue;
        
        // Calculate collateral to seize (debt value + bonus)
        uint256 collateralToSeizeValue = debtToRepayValue;
        uint256 bonusValue = (collateralToSeizeValue * LIQUIDATION_BONUS) / 1e18;
        uint256 totalSeizeValue = collateralToSeizeValue + bonusValue;
        uint256 collateralToSeize = (totalSeizeValue * 1e18) / getEthPrice();
        
        require(collateralToSeize <= pos.collateralAmount, "Cannot seize more than collateral");
        
        // Transfer debt tokens from liquidator
        dusd.transferFrom(msg.sender, address(this), dusdToRepay);
        dusc.transferFrom(msg.sender, address(this), duscToRepay);
        
        // Update position
        pos.collateralAmount -= collateralToSeize;
        pos.dusdDebt -= dusdToRepay;
        pos.duscDebt -= duscToRepay;
        
        // Update reserves
        dusdReserves += dusdToRepay;
        duscReserves += duscToRepay;
        
        // Burn repaid tokens
        dusd.burn(address(this), dusdToRepay);
        dusc.burn(address(this), duscToRepay);
        
        // Transfer collateral to liquidator
        mweth.transfer(msg.sender, collateralToSeize);
        
        emit Liquidate(user, msg.sender, collateralToSeize, dusdToRepay + duscToRepay);
    }

    function addReserves(uint256 dusdAmount, uint256 duscAmount) external {
        dusd.transferFrom(msg.sender, address(this), dusdAmount);
        dusc.transferFrom(msg.sender, address(this), duscAmount);
        dusdReserves += dusdAmount;
        duscReserves += duscAmount;
    }
}
