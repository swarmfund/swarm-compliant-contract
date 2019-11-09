pragma solidity ^0.5.0;

contract IContributorRestrictions {
    function checkContributor(address account) external view returns (bool);
}