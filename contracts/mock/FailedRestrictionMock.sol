pragma solidity ^0.5.0;

import "../rules/ITransferRestriction.sol";


/**
 * @title FailedRestrictionMock contract
 * @dev ITransferRestriction which will fail.
 */
contract FailedRestrictionMock is ITransferRestriction {
    function authorize(address src20, address from, address to, uint256 value) external returns (bool) {
        return false;
    }
}
