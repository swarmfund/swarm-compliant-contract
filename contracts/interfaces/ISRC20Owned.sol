pragma solidity ^0.5.0;

/**
    @title SRC20 interface for owners
 */
interface ISRC20Owned {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event KYAUpdated(bytes32 kyaHash, string kyaUrl, address restrictions, address rules);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    event TokenFrozen();
    event TokenUnfrozen();

    function updateKYA(bytes32 kyaHash, string calldata kyaUrl, address restrictions, address rules) external returns (bool);
    function transferTokenForced(address from, address to, uint256 value) external returns (bool);

    function burnAccount(address account, uint256 value) external returns (bool);
}
