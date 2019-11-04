pragma solidity ^0.5.0;

import "../rules/ContributionRules.sol";

contract PassContributionRules is ContributionRules{
    function checkContribution() {
        return true;
    }
}