pragma solidity ^0.5.0;

import "../rules/ITransferRestriction.sol";

/**
 * @title FailedRestrictionMock contract
 * @dev ITransferRestriction which will fail.
 */
contract FailedRestrictionMock is ITransferRestriction {
    function setSRC(address src20) external returns (bool) {
        return true;
    }

    function authorize(address from, address to, uint256 value) external returns (bool) {
        return false;
    }
}
