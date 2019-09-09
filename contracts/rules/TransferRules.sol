pragma solidity ^0.5.10;

import "./ManualApproval.sol";
import "./Whitelisted.sol";

contract TransferRules is ManualApproval, Whitelisted {
    address private _src20;

    modifier onlySRC20 {
        require(msg.sender == _src20);
        _;
    }

    function setSRC(address src20) external returns (bool) {
        require(_src20 == address(0), "SRC20 already set");
        _src20 = src20;
        return true;
    }

    function doTransfer(address from, address to, uint256 value) external onlySRC20 returns (bool) {
        if (isWhitelisted(from) && isWhitelisted(from)) {
            if (isGrayListed(from) || isGrayListed(to)) {
                _transferRequest(from, to, value);
            } else {
                ISRC20(_src20).executeTransfer(from, to, value);
            }
        }

        // todo...

        return true;
    }
}
