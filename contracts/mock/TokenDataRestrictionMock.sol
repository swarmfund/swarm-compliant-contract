pragma solidity ^0.5.0;

import "../rules/ITransferRestriction.sol";
import "../token/ISRC20.sol";

/**
 * @title TokenDataRestrictionMock contract
 * @dev ITransferRestriction which will pass with token data emitted in event.
 */
contract TokenDataRestrictionMock is ITransferRestriction {
    ISRC20 _src20;

    uint256 totalSupply;
    uint256 balance;
    uint256 nonce;

    event TokenData(uint256 totalSupply, uint256 balance, uint256 nonce);

    function setSRC(address src20) external returns (bool) {
        require(address(_src20) == address(0), "SRC contract already set");

        _src20 = ISRC20(src20);
        return true;
    }

    function authorize(address from, address to, uint256 value) external returns (bool) {
        totalSupply = _src20.totalSupply();
        balance = _src20.balanceOf(from);
        nonce = _src20.getTransferNonce(from);

        return true;
    }

    function emitTokenData() external returns (bool) {
        emit TokenData(totalSupply, balance, nonce);
        return true;
    }
}
