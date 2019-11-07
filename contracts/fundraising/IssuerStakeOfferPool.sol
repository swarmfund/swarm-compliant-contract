pragma solidity ^0.5.10;

contract IssuerStakeOfferPool {
    address public src20Registry;
    uint256 public minAmountNeeded;
    uint256 public maxMarkup;

    function register(uint256 swmAmount, uint256 markup) external returns (bool) {
        return true;
    }

    function isStakeOfferer(address account) external view returns (bool) {
        return true;
    }
}