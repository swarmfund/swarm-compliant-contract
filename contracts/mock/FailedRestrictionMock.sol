pragma solidity ^0.5.0;

import "../interfaces/ITransferRules.sol";

/**
 * @title FailedRestrictionMock contract
 * @dev ITransferRestriction which will fail.
 */
contract FailedRestrictionMock is ITransferRules {
    function setSRC(address src20) external returns (bool) {
        // eliminate warnings
        address s; s = src20;
        return true;
    }

    function authorize(address from, address to, uint256 value) external pure returns (bool) {
        // eliminate warnings
        address f; f = from;
        address t; t = to;
        uint256 v; v = value;
        return false;
    }

    function doTransfer(address from, address to, uint256 value) external returns (bool) {
        // eliminate warnings
        address f; f = from;
        address t; t = to;
        uint256 v; v = value;
        return false;
    }
}
