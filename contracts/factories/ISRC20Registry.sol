pragma solidity ^0.5.0;

contract ISRC20Registry {
    function put(address token, address roles, address tokenOwner) external returns (bool);
}