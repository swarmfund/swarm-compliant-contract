pragma solidity ^0.5.0;

/**
 * @title SRC20 public interface
 */
interface ISRC20 {
    // SRC20 interface
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    function getKYA() external view returns (bytes32, string memory, address);

    function transferToken(address to, uint256 value, uint256 nonce, uint256 expirationTime, 
        bytes32 msgHash, bytes calldata signature) external returns (bool);
    function transferTokenFrom(address from, address to, uint256 value, uint256 nonce,
        uint256 expirationTime, bytes32 hash, bytes calldata signature) external returns (bool);

    function getTransferNonce() external view returns (uint256);
    function isAuthority(address account) external view returns (bool);
    function isTokenFrozen() external view returns (bool);
    function isFrozen(address account) external view returns (bool);

    function getTransferNonce(address account) external view returns (uint256);

    // ERC20 part-like interface
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);

    function increaseAllowance(address spender, uint256 value) external returns (bool);
    function decreaseAllowance(address spender, uint256 value) external returns (bool);
}