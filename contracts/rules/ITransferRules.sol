pragma solidity ^0.5.0;


/**
 * @title ITransferRules interface
 * @dev Represents interface for any on-chain SRC20 transfer restriction 
 * implementation. Transfer Restriction registries are expected to follow 
 * same interface, managing multiply transfer restriction implementations.
 */
interface ITransferRules {
    function setSRC(address src20) external returns (bool);
    function authorize(address from, address to, uint256 value) external returns (bool);
    function doTransfer(address from, address to, uint256 value) external returns (bool);
}
