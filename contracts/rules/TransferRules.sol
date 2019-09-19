pragma solidity ^0.5.0;

import "./ManualApproval.sol";
import "./Whitelisted.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/ITransferRules.sol";

/*
 * @title TransferRules contract
 * @dev Contract that is checking if on-chain rules for token transfers are concluded.
 */
contract TransferRules is ITransferRules, ManualApproval, Whitelisted {
    address private _src20;

    modifier onlySRC20 {
        require(msg.sender == _src20);
        _;
    }

    constructor(address owner) public {
        _transferOwnership(owner);
    }

    function setSRC(address src20) external returns (bool) {
        require(_src20 == address(0), "SRC20 already set");
        _src20 = src20;
        _setSRO20ManualAllover(_src20);
        return true;
    }

    function authorize(address from, address to, uint256 value) public returns (bool) {
        return (isWhitelisted(from) || isGrayListed(from)) &&
               (isWhitelisted(to) || isGrayListed(to));
    }

    function doTransfer(address from, address to, uint256 value) external onlySRC20 returns (bool) {
        if (isWhitelisted(from) && isWhitelisted(from)) {
            if (isGrayListed(from) || isGrayListed(to)) {
                _transferRequest(from, to, value);
            } else {
                ISRC20(_src20).executeTransfer(from, to, value);
            }
        }

        if (isGrayListed(from) && isWhitelisted(to) ||
            isWhitelisted(from) && isGrayListed(to) ||
            isGrayListed(from) && isGrayListed(to)
        ) {
            ISRC20(_src20).executeTransfer(from, to, value);
        }

        return true;
    }
}
