pragma solidity ^0.5.0;

import "./ManualApproval.sol";
import "./Whitelisted.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/ITransferRules.sol";
import "../interfaces/ITransferRestrictions.sol";

/*
 * @title TransferRules contract
 * @dev Contract that is checking if on-chain rules for token transfers are concluded.
 * It implements whitelist and gray list.
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

    /**
    * @dev Set for what contract this rules are.
    *
    * @param src20 - Address of SRC20 contract.
    */
    function setSRC(address src20) external returns (bool) {
        require(_src20 == address(0), "SRC20 already set");
        _src20 = src20;
        _setSRC20ManualAllover(_src20);
        return true;
    }

    /**
    * @dev Checks if transfer passes transfer rules.
    *
    * @param from The address to transfer from.
    * @param to The address to send tokens to.
    * @param value The amount of tokens to send.
    */
    function authorize(address from, address to, uint256 value) public returns (bool) {
        return (isWhitelisted(from) || isGrayListed(from)) &&
        (isWhitelisted(to) || isGrayListed(to));
    }

    /**
    * @dev Do transfer and checks where funds should go. If both from and to are
    * on the whitelist funds should be transferred but if one of them are on the
    * gray list token-issuer/owner need to approve transfer.
    *
    * @param from The address to transfer from.
    * @param to The address to send tokens to.
    * @param value The amount of tokens to send.
    */
    function doTransfer(address from, address to, uint256 value) external onlySRC20 returns (bool) {
        require(authorize(from, to, value), "Transfer not authorized");

        if (isGrayListed(from) || isGrayListed(to)) {
            _transferRequest(from, to, value);
            return true;
        }

        require(ISRC20(_src20).executeTransfer(from, to, value), "SRC20 transfer failed");

        return true;
    }
}
