pragma solidity ^0.5.0;

import "../interfaces/IContributionRules.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract ContributionRules is IContributionRules {
    using SafeMath for uint256;

    uint256 public minAmount;
    uint256 public maxAmount;

    constructor(
        uint256 _minAmount,
        uint256 _maxAmount
    ) public {
        maxAmount = _maxAmount;
        minAmount = _minAmount;
    }

    function isGreaterThenMax(uint256 amount) external returns (bool, uint256) {
        return (amount > maxAmount, amount > maxAmount ? amount.sub(amount.sub(maxAmount)) : 0);
    }

    function isBelowMin(uint256 amount) external returns (bool) {
        return amount < minAmount;
    }
}