pragma solidity ^0.5.0;

import "../rules/ITransferRules.sol";
import "../token/SRC20.sol";

/**
 * @title SuccessfulRestrictionMock contract
 * @dev ITransferRestriction which will pass.
 */
contract SuccessfulRestrictionMock is ITransferRules {
    function setSRC(address src20) external returns (bool) {
        return true;
    }

    function authorize(address from, address to, uint256 value) external returns (bool) {
        return true;
    }
}
