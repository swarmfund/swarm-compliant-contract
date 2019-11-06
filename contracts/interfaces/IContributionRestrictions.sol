pragma solidity ^0.5.0;

contract IContributionRestrictions {
    function checkContributor(address account) external view returns (bool);
}