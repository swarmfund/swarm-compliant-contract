pragma solidity ^0.5.0;

contract IContributionRules {
    function isBelowMin(uint256 amount) external returns (bool);
    function isGreaterThenMax(uint256 amount) external returns (bool, uint256);
}