pragma solidity ^0.5.0;

import "../rules/ITransferRestriction.sol";
import "../token/ISRC20.sol";


/**
 * @title TokenDataRestrictionMock contract
 * @dev ITransferRestriction which will pass with token data emitted in event.
 */
contract TokenDataRestrictionMock is ITransferRestriction {
    uint256 totalSupply;
    uint256 balance;
    uint256 nonce;

    event TokenData(uint256 totalSupply, uint256 balance, uint256 nonce);

    function authorize(address src20, address from, address to, uint256 value) external returns (bool) {
        ISRC20 token = ISRC20(src20);

        totalSupply = token.totalSupply();
        balance = token.balanceOf(from);
        nonce = token.getTransferNonce(from);

        return true;
    }

    function emitTokenData() external returns (bool) {
        emit TokenData(totalSupply, balance, nonce);
        return true;
    }
}
