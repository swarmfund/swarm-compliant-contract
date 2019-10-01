pragma solidity ^0.5.0;

/**
    @title SRC20 interface for owners
 */
interface ISRC20Owned {
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function transferTokenForced(address from, address to, uint256 value) external returns (bool);

    function burnAccount(address account, uint256 value) external returns (bool);
}
