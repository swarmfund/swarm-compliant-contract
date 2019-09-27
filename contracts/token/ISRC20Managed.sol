pragma solidity ^0.5.0;

/**
    @title SRC20 interface for managers
 */
interface ISRC20Managed {
    event ManagementTransferred(address indexed previousManager, address indexed newManager);

    function burn(address account, uint256 value) external returns (bool);
    function mint(address account, uint256 value) external returns (bool);

    function renounceManagement() external returns (bool);
    function transferManagement(address newManager) external returns (bool);

    function manager() external view returns (address);
}
