pragma solidity ^0.5.0;

contract IContributorRestrictions {
    function whitelistAccount(address account) external;    
    function isAllowed(address account) external view returns (bool);
}