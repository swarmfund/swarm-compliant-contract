pragma solidity ^0.5.0;

/**
 * @title ITransferRestrictions interface
 * @dev Represents interface for any on-chain SRC20 transfer restriction
 * implementation. Transfer Restriction registries are expected to follow
 * same interface, managing multiply transfer restriction implementations.
 *
 * It is intended to implementation of this interface be used for transferToken()
 */
interface ITransferRestrictions {
    function authorize(address from, address to, uint256 value) external returns (bool);
}
