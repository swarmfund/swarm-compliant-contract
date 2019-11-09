pragma solidity ^0.5.0;

contract IContributionRules {
    function checkContribution(uint256 amount) external returns (bool);
}