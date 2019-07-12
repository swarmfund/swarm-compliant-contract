pragma solidity ^0.5.0;

/**
    @title SRC20 interface for owners
 */
interface ISRC20Owned {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event KYAUpdated(bytes32 kyaHash, string kyaUrl, address restrictions);
    event AuthorityAdded(address indexed account);
    event AuthorityRemoved(address indexed account);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    event TokenFrozen();
    event TokenUnfrozen();

    function updateKYA(bytes32 kyaHash, string calldata kyaUrl, address restrictions) external returns (bool);
    function transferTokenForced(address from, address to, uint256 value) external returns (bool);

    function addAuthority(address account) external;
    function removeAuthority(address account) external;
    function freezeAccount(address account) external;
    function unfreezeAccount(address account) external;
    function freezeToken() external;
    function unfreezeToken() external;
    function burnAccount(address account, uint256 value) external returns (bool);
}
